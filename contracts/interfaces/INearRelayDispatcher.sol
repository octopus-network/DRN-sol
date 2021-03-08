// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.4.22 <0.9.0;

interface INearRelayDispatcher {
    function scoringStartAt() external pure returns (uint256);

    function totalScore(uint256 startAt) external pure returns (uint64);

    function scoreOf(uint256 startAt, address relayer) external pure returns (uint64);

    function relayLightClientBlock(bytes calldata data) external;

    function claimRewards() external;

    function relayInvestmentStrategy(bytes calldata data) external;

    function relayCommandFromDao(bytes calldata data) external;
}
