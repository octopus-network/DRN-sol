// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.4.22 <0.9.0;

interface INearRelayDispatcher {
    function totalScore() external pure returns (uint32);

    function scoreOf(address relayer) external pure returns (uint32);

    function relayLightClientBlock(bytes calldata data) external;

    function claimRewards() external;

    function relayInvestmentStrategy(bytes calldata data) external;

    function relayCommandFromDao(bytes calldata data) external;
}
