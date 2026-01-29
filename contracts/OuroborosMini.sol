// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

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
