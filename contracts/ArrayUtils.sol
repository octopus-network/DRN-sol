// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.4.22 <0.9.0;

library ArrayUtils {
    function findIndex(address[] storage addrArray, address target) private view returns (uint256) {
        uint256 i = 0;
        while (addrArray[i] != target && i < addrArray.length) {
            i++;
        }
        return i;
    }

    function removeByIndex(address[] storage addrArray, uint256 index) internal returns (address[] storage) {
        if (index >= addrArray.length) return addrArray;
        for (uint256 i = index; i < addrArray.length - 1; i++) {
            addrArray[i] = addrArray[i + 1];
        }
        addrArray.pop();
        return addrArray;
    }

    function removeByFind(address[] storage addrArray, address target) internal returns (address[] storage) {
        uint256 index = findIndex(addrArray, target);
        return removeByIndex(addrArray, index);
    }
}
