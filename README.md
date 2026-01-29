# Ouroboros; or, cyclic counterfactual deployments

We want to deploy two contracts, `Ouro` and `Boros`, which need to call each other.

This is not a hard problem to solve. Here's one simple solution:

```solidity
contract Ouro {
    address public boros;
    bool public initialized = false;

    function initialize(address _boros) public {
        require(!initialized, "Contract was already initialized");

        boros = _boros;
        initialized = true;
    }
}

contract Boros {
    address public ouro;

    constructor(address _ouro) {
        ouro = _ouro;
    }
}

contract Deployer {
    function deploy() public returns (address, address) {
        Ouro ouro = new Ouro();
        Boros boros = new Boros(address(ouro));
        ouro.initialize(address(boros));

        return (address(ouro), address(boros));
    }
}
```

The only tricky part is making sure that `initialize` is called within the same transaction to prevent front-running.

## Constraint 1: deterministic addresses

What if we want to deploy `Ouro` and `Boros` in multiple chains at the same address?

Not much changes: we can use the previous solution, except we deploy each contract using a `CREATE2` factory.

## Constraint 2: no storage

Now let's say that we don't want `Ouro` and `Boros` to use storage. This makes the problem harder, but not that much
harder.

Since we can't use storage, they need to get the address of each other in some other way. The simplest approach is
to make it part of the contract, either hardcoding it or making it an immutable value:

```solidity
contract Ouro {
    function getBoros() public pure returns (address) {
        return "0x...";
    }
}

contract Boros {
    function getOuro() public pure returns (address) {
        return "0x...";
    }
}
```

This means that we must know the addresses of both contracts before we finish writing them.

The usual answer to this problem is to use a `CREATE2` factory, which we were already doing, but that won't work here:

- To know the address of `Ouro` we need to know its init code
- The init code of `Ouro` includes the address of `Boros`, so we need that first
- To know the address of `Boros` we need to know its init code
- The init code of `Boros` includes the address of `Ouro`
- To know the address of `Ouro`...

You get the idea.

One possible solution is to have a third contract, also deployed with `CREATE2`, that has in its storage
the address of `Ouro` and `Boros`, but this would be inefficient and feels like cheating anyway, so let's
say we also want this to be efficient.

A better solution is to use `CREATE3`, which lets us know the address of each contract in advance in a way
that doesn't depend on the init code, only on the salt we provide. But `CREATE3` has the downside of needing
`msg.sender` protection, so let's add another constraint.

## Constraint 3: anyone can deploy the contracts

If anyone can deploy the contracts, we can't use `CREATE3` without the risk of being front-runned. If the
contracts take the address of the other contract from their code, we can't use `CREATE2`. Is this an
unsolvable problem?

## The solution

It is solvable.

The previous discussion has an assumption that makes sense but it's not technically correct: that if a contract
has a hardcoded value in its runtime code, then that value will also be included in its init code. This is not true.
The init code normally copies the full runtime code from its own code, but it doesn't _have_ to.

What if `Ouro` and `Boros` get each other address from their own runtime code but that's not included in the
init code?

Before thinking how to accomplish that, let's assume something: our contracts will have its normal, solc-generated
bytecode but they will also have an extra 20 bytes at the end with the address of each other. Then we can use
some simple assembly to get the address of the paired contract:

```solidity
contract Ouro {
    function getBoros() public pure returns (address boros) {
        assembly {
            let p := mload(0x40)
            codecopy(add(p, 12), sub(codesize(), 20), 20)
            boros := mload(p)
        }
    }
}

contract Boros {
    function getOuro() public pure returns (address ouro) {
        assembly {
            let p := mload(0x40)
            codecopy(add(p, 12), sub(codesize(), 20), 20)
            ouro := mload(p)
        }
    }
}
```

To keep things simple, this is the only thing our contracts will do. If we compile those contracts, solc gives us their init and runtime codes. We are only going to use the runtime code.

So here's our problem: we need to write an init code that deploys a runtime code `R` and adds an address `A` at the end, but without including `A` in that init code.

One way to do that is to get `A` from somewhere else, and a simple option is to just call the `CALLER`. The following bytecode illustrates the idea to deploy an `Ouro` contract with the address of `Boros` at the end:

```
// 37 is the length of this bytecode if we omit the runtime code we include at the end to code-copy it; we'll call this value INIT_LENGTH
PUSH1 37
DUP1
CODESIZE
SUB

// RUNTIME_LENGTH, the length of the runtime code included at the end, is equal to `codesize - INIT_LENGTH`

// stack = [RUNTIME_LENGTH, INIT_LENGTH]

DUP1
SWAP2
// stack = [INIT_LENGTH, RUNTIME_LENGTH, RUNTIME_LENGTH]

PUSH1 0x20 // destOffset = start of runtime code to return
// stack = [0x20, INIT_LENGTH, RUNTIME_LENGTH, RUNTIME_LENGTH]

CODECOPY

// stack = [RUNTIME_LENGTH]
// memory: [00..00, RUNTIME_CODE]

// args
PUSH4 0x2b246cb6 // getBorosAddress()
PUSH0
MSTORE

// stack = [RUNTIME_LENGTH]
// memory: [00..{getBorosAddress()}, RUNTIME_CODE]

// static call
PUSH1 20 // retSize = address length
// ret offset: 0x20 + RUNTIME_LENGTH
PUSH1 0x20
DUP3
ADD
// args: getBorosAddress()
PUSH1 4  // argsSize
PUSH1 28 // argsOffset

CALLER   // address
GAS      // gas
STATICCALL

POP // for simplicity we assume the static call succeeds

// stack = [RUNTIME_LENGTH]
// memory = [00..{getBorosAddress()}, {RUNTIME_CODE}{BOROS_ADDRESS}]

// return
PUSH1 20
ADD        // size = runtime code + 20 (added address)
PUSH1 0x20 // offset
RETURN

// start of runtime code (0x010203)
ADD
MUL
SUB
```

We basically take the runtime code from this init code but call the `getBorosAddress()` from the caller and append it at the end of the returned data. To keep things short, in this example the
runtime code is just `0x010203`, but that runtime code can be changed to anything and it will continue working fine.

The init code to deploy `Boros` is the same one, except we change the 4 byte method we call on the caller to the selector of `getOuroAddress()`.

Now here's the important part: **if we use `CREATE2` to deploy these init codes, the addresses can be known in advance and included in the contract that deploys them.**

Putting all together:

```solidity
contract MiniDeployer {
    address public ouro = 0xc3698B93B2334CAdCddC669276104ec48cE60f8C;
    address public boros = 0x2F2B308D9E0A6958a73727cDA948BAfDD654855F;

    function deploy(bytes32 salt) public {
        address a;

        // deploy ouro
        assembly {
            let p := mload(0x40)
            mstore(
                p,
                //////////////////////////////////////////////////////////////////
                0x60258038038091602039632b246cb65f526014602082016004601c335afa5060
            )
            mstore(
                add(p, 32),
                //////////////////////////////////////////////////////////////////
                0x14016020f3010203000000000000000000000000000000000000000000000000
            )
            a := create2(0, p, 40, salt)
        }

        ouro = a;

        // deploy boros
        assembly {
            let p := mload(0x40)
            mstore(
                p,
                //////////////////////////////////////////////////////////////////
                0x602580380380916020396327db63c75f526014602082016004601c335afa5060
            )
            mstore(
                add(p, 32),
                //////////////////////////////////////////////////////////////////
                0x14016020f3010203000000000000000000000000000000000000000000000000
            )
            a := create2(0, p, 40, salt)
        }

        boros = a;

    }

    function getOuroAddress() public view returns (bytes20) {
      return bytes20(ouro);
    }

    function getBorosAddress() public view returns (bytes20) {
      return bytes20(boros);
    }
}
```

If we want to deploy our actual contracts, we just need to use the proper runtime code instead of `0x010203` and re-calculate the addresses hardcoded in the deployer. Check [`Ouroboros.sol`](contracts/Ouroboros.sol) to see the full example, but the idea is exactly the same.

To see this in action, run `pnpm hardhat run scripts/deploy.sol`.

For simplicity, the `Deployer` is deployed using an EOA. This lets us know the address of the `Deployer` in advance, which in turn we use to compute the addresses of `Ouro` and `Boros`. But we could easily modify the code so that `Deployer` is deployed with a `CREATE2` factory, and instead of including the addresses of `Ouro`/`Boros` (which would generate a cycle), we include the hashes of their init codes, and compute their addresses in the constructor of `Deployer` using `address(this)`.

## Can you verify these contracts in Etherscan?

Lol no.

## Are you sure?

Well, actually...

Solc can include some metadata at the end of the bytecode that Etherscan ignores (or it marks as a partial match; I don't remember the details). This metadata is a CBOR-encoded object. I think we could put the paired contract address there, which would make everything more complicated but seems doable.
