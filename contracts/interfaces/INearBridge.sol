// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.4.22 <0.9.0;

interface INearBridge {
    event BlockHashAdded(uint64 indexed height, bytes32 blockHash);

    function addLightClientBlock(bytes calldata data) external;
}
