// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.4.22 <0.9.0;

interface IRelayRegistry {
    function isRelayer(address targetAddr) external view returns (bool);

    function isCandidate(address targetAddr) external view returns (bool);

    function register() external payable;

    function activate() external;

    function quit() external;

    function deposit() external payable;

    function withdraw(uint256) external;

    function withdrawAll() external;

    function distributeRewards() external;

    function refundGasFee(address payable sender, uint256 amount) external;

    function initDispatcher(address targetAddr) external;

    function setRewardsRatio(uint16 value) external;

    function setFreezingPeriod(uint256 value) external;
}
