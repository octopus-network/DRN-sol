// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.4.22 <0.9.0;

import 'rainbow-bridge-sol/nearprover/contracts/INearProver.sol';

contract NearProverMock is INearProver {
    function proveOutcome(bytes memory proofData, uint64 blockHeight) public view override returns (bool) {
        return true;
    }
}
