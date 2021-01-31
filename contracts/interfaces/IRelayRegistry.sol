// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.4.22 <0.9.0;

interface IRelayRegistry {
    function register() external payable;

    function activate() external;

    function quit() external;

    function deposit() external payable;

    function withdraw(uint256) external;

    function withdrawAll() external;

    function distributeRewards() external;
}
