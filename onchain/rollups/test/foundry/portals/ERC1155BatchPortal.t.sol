// Copyright 2023 Cartesi Pte. Ltd.

// SPDX-License-Identifier: Apache-2.0
// Licensed under the Apache License, Version 2.0 (the "License"); you may not use
// this file except in compliance with the License. You may obtain a copy of the
// License at http://www.apache.org/licenses/LICENSE-2.0

// Unless required by applicable law or agreed to in writing, software distributed
// under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

/// @title ERC-1155 Batch Transfer Portal Test
pragma solidity ^0.8.8;

import {Test} from "forge-std/Test.sol";
import {ERC1155BatchPortal} from "contracts/portals/ERC1155BatchPortal.sol";
import {IERC1155BatchPortal} from "contracts/portals/IERC1155BatchPortal.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {IInputBox} from "contracts/inputs/IInputBox.sol";
import {InputBox} from "contracts/inputs/InputBox.sol";

contract BatchToken is ERC1155 {
    constructor(
        address tokenOwner,
        uint256[] memory tokenIds,
        uint256[] memory totalSupplies
    ) ERC1155("BatchToken") {
        _mintBatch(tokenOwner, tokenIds, totalSupplies, "");
    }
}

contract BadERC1155Receiver {}

/* Destination contract that manages ERC-1155 transfers */
contract ERC1155Receiver is IERC1155Receiver {
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    function supportsInterface(
        bytes4 interfaceID
    ) external pure returns (bool) {
        return
            interfaceID == 0x01ffc9a7 || // ERC-165 support
            interfaceID == 0x4e2312e0; // ERC-1155 `ERC1155TokenReceiver`
    }
}

contract ERC1155BatchPortalTest is Test {
    IInputBox inputBox;
    IERC1155BatchPortal portal;
    IERC1155 token;
    address alice;
    address dapp;
    address bob;

    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] values
    );

    function setUp() public {
        inputBox = new InputBox();
        portal = new ERC1155BatchPortal(inputBox);
        alice = vm.addr(1);
        dapp = vm.addr(2);
        bob = vm.addr(3);
    }

    function testGetInputBoxBatch() public {
        assertEq(address(portal.getInputBox()), address(inputBox));
    }

    function testBatchERC1155DepositEOA(
        bytes calldata baseLayerData,
        bytes calldata execLayerData,
        uint256[] calldata totalSupplies
    ) public {
        vm.assume(totalSupplies.length > 0);
        uint256[] memory tokenIds = generateTokenIDs(totalSupplies);
        uint256[] memory values = generateValues(totalSupplies);

        // Mint ERC1155 tokens for Alice
        token = new BatchToken(alice, tokenIds, totalSupplies);

        // Start impersonating Alice
        vm.startPrank(alice);

        // Allow the portal to withdraw the token from Alice
        token.setApprovalForAll(address(portal), true);

        // Expect TransferBatch to be emitted with the right arguments
        vm.expectEmit(true, true, true, true);
        emit TransferBatch(address(portal), alice, dapp, tokenIds, values);

        portal.depositBatchERC1155Token(
            token,
            dapp,
            tokenIds,
            values,
            baseLayerData,
            execLayerData
        );

        // Check the token balances
        for (uint256 i; i < totalSupplies.length; ++i) {
            assertEq(token.balanceOf(dapp, tokenIds[i]), values[i]);
            assertEq(
                token.balanceOf(alice, tokenIds[i]),
                totalSupplies[i] - values[i]
            );
        }

        // Check the DApp's input box
        assertEq(inputBox.getNumberOfInputs(dapp), 1);
    }

    function testNotApprovedBatchERC1155DepositEOA(
        bytes calldata baseLayerData,
        bytes calldata execLayerData,
        uint256[] calldata totalSupplies
    ) public {
        vm.assume(totalSupplies.length > 0);
        uint256[] memory tokenIds = generateTokenIDs(totalSupplies);
        uint256[] memory values = generateValues(totalSupplies);

        // Mint tokens for Alice
        token = new BatchToken(alice, tokenIds, values);

        // Start impersonating Alice
        vm.startPrank(alice);

        vm.expectRevert("ERC1155: caller is not token owner or approved");
        portal.depositBatchERC1155Token(
            token,
            dapp,
            tokenIds,
            values,
            baseLayerData,
            execLayerData
        );
    }

    function testBatchERC1155DepositContract(
        bytes calldata baseLayerData,
        bytes calldata execLayerData,
        uint256[] calldata totalSupplies
    ) public {
        vm.assume(totalSupplies.length > 0);
        uint256[] memory tokenIds = generateTokenIDs(totalSupplies);
        uint256[] memory values = generateValues(totalSupplies);

        // Use an ERC1155 Receiver contract as a destination
        dapp = address(new ERC1155Receiver());

        // Mint ERC1155 tokens for Alice
        token = new BatchToken(alice, tokenIds, totalSupplies);

        // Start impersonating Alice
        vm.startPrank(alice);

        // Allow the portal to withdraw tokens from Alice
        token.setApprovalForAll(address(portal), true);

        // Expect TransferBatch to be emitted with the right arguments
        vm.expectEmit(true, true, true, true);
        emit TransferBatch(address(portal), alice, dapp, tokenIds, values);

        portal.depositBatchERC1155Token(
            token,
            dapp,
            tokenIds,
            values,
            baseLayerData,
            execLayerData
        );

        // Check the token balances
        for (uint256 i; i < totalSupplies.length; ++i) {
            assertEq(token.balanceOf(dapp, tokenIds[i]), values[i]);
            assertEq(
                token.balanceOf(alice, tokenIds[i]),
                totalSupplies[i] - values[i]
            );
        }

        // Check the DApp's input box
        assertEq(inputBox.getNumberOfInputs(dapp), 1);
    }

    function testNotReceiverBatchERC1155DepositContract(
        bytes calldata baseLayerData,
        bytes calldata execLayerData,
        uint256[] calldata totalSupplies
    ) public {
        vm.assume(totalSupplies.length > 0);
        uint256[] memory tokenIds = generateTokenIDs(totalSupplies);
        uint256[] memory values = generateValues(totalSupplies);

        // Use a contract as a destination that does NOT implement ERC1155 Receiver
        dapp = address(new BadERC1155Receiver());

        // Mint ERC1155 tokens for Alice
        token = new BatchToken(alice, tokenIds, totalSupplies);

        // Start impersonating Alice
        vm.startPrank(alice);

        // Allow the portal to withdraw tokens from Alice
        token.setApprovalForAll(address(portal), true);

        vm.expectRevert("ERC1155: transfer to non-ERC1155Receiver implementer");
        portal.depositBatchERC1155Token(
            token,
            dapp,
            tokenIds,
            values,
            baseLayerData,
            execLayerData
        );

        // Check the DApp's input box
        assertEq(inputBox.getNumberOfInputs(dapp), 0);
    }

    // HELPER FUNCTIONS

    function generateTokenIDs(
        uint256[] calldata totalSupplies
    ) internal pure returns (uint256[] memory) {
        uint256[] memory tokenIds = new uint256[](totalSupplies.length);
        for (uint256 i; i < totalSupplies.length; ++i) tokenIds[i] = i;
        return tokenIds;
    }

    function generateValues(
        uint256[] calldata totalSupplies
    ) internal pure returns (uint256[] memory) {
        uint256[] memory values = new uint256[](totalSupplies.length);
        for (uint256 i; i < totalSupplies.length; ++i) {
            uint256 value = uint256(
                keccak256(abi.encodePacked(i, totalSupplies[i]))
            );
            values[i] = (value <= totalSupplies[i]) ? value : totalSupplies[i];
        }
        return values;
    }
}
