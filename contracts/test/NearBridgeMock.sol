// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.4.22 <0.9.0;

import '../interfaces/INearBridge.sol';

contract NearBridgeMock is INearBridge {
    function addLightClientBlock(bytes calldata data) public override returns (bool) {
        return true;
    }
}
