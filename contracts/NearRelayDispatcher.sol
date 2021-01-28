// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

contract NearRelayDispatcher {
    event RelayLog(uint64 indexed height, address relayer, uint32 score);
    event RewardsClaimed();

    mapping(uint256 => bytes) public blockDataMap;

    mapping(address => uint32) public scoreOf;

    constructor() public {}

    function relayLightClientBlock(bytes calldata data) public {}

    function claimRewards() public {}

    function relayInvestmentStrategy(bytes calldata data) public {}

    function relayCommandFromDao(bytes calldata data) public {}
}
