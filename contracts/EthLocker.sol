// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.4.22 <0.9.0;

contract EthLocker {
    event Locked(address indexed sender, uint256 amount, string accountId);
    event Unlocked(uint128 amount, address recipient);

    address public dispatcherAddr;
    uint16 public reserveRatio;
    uint16 public rewardsRatio;
    address[] public inUseStrategyAddrList;
    uint256 public lockedEth;

    constructor() public {}

    // Fundamental
    function setDispatcher(address targetAddress) public {}

    function lockEth(uint256 amount, string memory accountId) public {}

    function unlockEth(bytes memory proofData, uint64 proofBlockHeight) public {}

    function burnResult(bytes memory proofData, uint64 proofBlockHeight) public view returns (address) {}

    // In case of loss
    function deposit() public payable {}

    // For investments
    function setReserveRatio(uint16 ratio) public {}

    function depositToStrategy(address strategyAddr, uint256 amount) public {}

    function withdrawFromStrategy(address strategyAddr, uint256 amount) public {}

    function withdrawAllFromStrategy(address strategyAddr, uint256 amount) public {}

    // Rewards
    function setRewardsRatio(uint16 ratio) public {}

    function transferRewards(address strategyAddr) public {}
}
