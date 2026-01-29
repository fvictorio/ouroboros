// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

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

contract Deployer {
    address public ouro = 0x5968DB143C95B6A48F7C13a8ca5E3093E051d60b;
    address public boros = 0x836c382D27aEb2812726e9472493ad345170e906;

    function deploy(bytes32 salt) public {
        address a;

        // deploy ouro
        assembly {
            let p := mload(0x40)

            mstore(
                add(p, 0),
                0x60258038038091602039632b246cb65f526014602082016004601c335afa5060
            )
            mstore(
                add(p, 32),
                0x14016020f36080604052348015600e575f5ffd5b50600436106026575f3560e0
            )
            mstore(
                add(p, 64),
                0x1c80636727e83514602a575b5f5ffd5b60306044565b604051603b9190609556
            )
            mstore(
                add(p, 96),
                0x5b60405180910390f35b5f6040516014803803600c830139805191505090565b
            )
            mstore(
                add(p, 128),
                0x5f73ffffffffffffffffffffffffffffffffffffffff82169050919050565b5f
            )
            mstore(
                add(p, 160),
                0x608182605a565b9050919050565b608f816079565b82525050565b5f60208201
            )
            mstore(
                add(p, 192),
                0x905060a65f8301846088565b9291505056fea164736f6c634300081e000a0000
            )

            a := create2(0, p, 222, salt)
        }

        ouro = a;

        // deploy boros
        assembly {
            let p := mload(0x40)

            mstore(
                add(p, 0),
                0x602580380380916020396327db63c75f526014602082016004601c335afa5060
            )
            mstore(
                add(p, 32),
                0x14016020f36080604052348015600e575f5ffd5b50600436106026575f3560e0
            )
            mstore(
                add(p, 64),
                0x1c8063523da7cc14602a575b5f5ffd5b60306044565b604051603b9190609556
            )
            mstore(
                add(p, 96),
                0x5b60405180910390f35b5f6040516014803803600c830139805191505090565b
            )
            mstore(
                add(p, 128),
                0x5f73ffffffffffffffffffffffffffffffffffffffff82169050919050565b5f
            )
            mstore(
                add(p, 160),
                0x608182605a565b9050919050565b608f816079565b82525050565b5f60208201
            )
            mstore(
                add(p, 192),
                0x905060a65f8301846088565b9291505056fea164736f6c634300081e000a0000
            )

            a := create2(0, p, 222, salt)
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
