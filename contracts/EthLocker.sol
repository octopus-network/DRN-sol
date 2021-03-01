// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.4.22 <0.9.0;

import '@openzeppelin/contracts/math/SafeMath.sol';
import {IRelayRegistry} from './interfaces/IRelayRegistry.sol';
import {IInvestmentStrategy} from './interfaces/IInvestmentStrategy.sol';
import 'rainbow-bridge-sol/nearbridge/contracts/Borsh.sol';
import './Locker.sol';

contract EthLocker is Locker {
    using SafeMath for uint256;

    event Locked(address indexed sender, uint256 amount, string accountId);
    event Unlocked(uint128 amount, address recipient);

    address public dispatcherAddr;

    uint256 public lockedEth;
    uint256 public minHarvest;
    // 10000 for 100.00%
    uint16 public reserveRatio;
    uint16 public rewardsRatio;

    address[] public inUseStrategyAddrList;
    mapping(address => uint256) strategyBalanceMap;

    struct BurnResult {
        uint128 amount;
        address payable recipient;
    }

    constructor(uint16 defaultReserveRatio, uint16 defaultRewardsRatio) public {
        reserveRatio = defaultReserveRatio;
        rewardsRatio = defaultRewardsRatio;
    }

    modifier onlyDispatcher {
        require(msg.sender == dispatcherAddr, 'Not dispatcher');
        _;
    }

    // Fundamental
    function setDispatcher(address targetAddr) public {
        if (dispatcherAddr == address(0)) {
            dispatcherAddr = targetAddr;
        }
    }

    function reserve() public view returns (uint256) {
        return lockedEth.mul(reserveRatio).div(10000);
    }

    function avaliableBalance() public view returns (uint256) {
        return address(this).balance.sub(reserve());
    }

    function avaliableRewards() public view returns (uint256) {
        uint256 harvestableProfits;
        for (uint256 i = 0; i < inUseStrategyAddrList.length; i++) {
            uint256 availableProfit = IInvestmentStrategy(inUseStrategyAddrList[i]).availableProfit();
            if (availableProfit >= minHarvest) {
                harvestableProfits = harvestableProfits.add(availableProfit);
            }
        }
        return harvestableProfits.mul(rewardsRatio);
    }

    function balanceFromStrategy(address strategyAddr) public view returns (uint256) {
        return IInvestmentStrategy(strategyAddr).balance();
    }

    function balanceFromAllStrategies() public view returns (uint256) {
        uint256 total;
        for (uint256 i = 0; i < inUseStrategyAddrList.length; i++) {
            total = total.add(balanceFromStrategy(inUseStrategyAddrList[i]));
        }
        return total;
    }

    function totalBalance() public view returns (uint256) {
        return address(this).balance.add(balanceFromAllStrategies());
    }

    function lockEth(address ethToken, string memory accountId) public payable {
        emit Locked(msg.sender, msg.value, accountId);
    }

    function burnResult(bytes memory proofData, uint64 proofBlockHeight)
        public
        returns (uint128 amount, address recipient)
    {
        ProofDecoder.ExecutionStatus memory status = _viewProof(proofData, proofBlockHeight);
        BurnResult memory result = _decodeBurnResult(status.successValue);
        amount = result.amount;
        recipient = result.recipient;
    }

    function unlockEth(bytes memory proofData, uint64 proofBlockHeight) public {
        ProofDecoder.ExecutionStatus memory status = _useProof(proofData, proofBlockHeight);
        BurnResult memory result = _decodeBurnResult(status.successValue);
        result.recipient.transfer(result.amount);
        emit Unlocked(result.amount, result.recipient);
    }

    // In case of loss
    function deposit() public payable {}

    // For investments
    function setReserveRatio(uint16 ratio) public onlyDispatcher {
        reserveRatio = ratio;
    }

    function setMinHarvest(uint16 ratio) public onlyDispatcher {
        minHarvest = ratio;
    }

    function depositToStrategy(address strategyAddr, uint256 amount) public onlyDispatcher {
        require(amount > 0, 'insufficient avaliable balance');
        IInvestmentStrategy(strategyAddr).deposit{value: amount}();
    }

    function depositAllToStrategy(address strategyAddr) public onlyDispatcher {
        uint256 avaliableAmount = address(this).balance.sub(reserve());
        if (avaliableAmount > 0) depositToStrategy(strategyAddr, avaliableAmount);
    }

    function withdrawFromStrategy(address strategyAddr, uint256 amount) public onlyDispatcher {
        IInvestmentStrategy(strategyAddr).withdraw(amount);
    }

    function withdrawAllFromStrategy(address strategyAddr) public onlyDispatcher {
        IInvestmentStrategy(strategyAddr).withdrawAll();
    }

    // Rewards
    function setRewardsRatio(uint16 ratio) public onlyDispatcher {
        rewardsRatio = ratio;
    }

    function transferRewards(address relayRegistryAddr) public onlyDispatcher {
        uint256 rewards = avaliableRewards();
        harvestAll();
        IRelayRegistry(relayRegistryAddr).deposit{value: rewards}();
    }

    function harvest(address strategyAddr) public onlyDispatcher {
        IInvestmentStrategy strategy = IInvestmentStrategy(strategyAddr);
        if (strategy.availableProfit() > minHarvest) {
            strategy.harvest();
        }
    }

    function harvestAll() public onlyDispatcher {
        for (uint256 i = 0; i < inUseStrategyAddrList.length; i++) {
            harvest(inUseStrategyAddrList[i]);
        }
    }

    function _decodeBurnResult(bytes memory data) internal pure returns (BurnResult memory result) {
        Borsh.Data memory borshData = Borsh.from(data);
        uint8 flag = borshData.decodeU8();
        require(flag == 0, 'ERR_NOT_WITHDRAW_RESULT');
        result.amount = borshData.decodeU128();
        bytes20 recipient = borshData.decodeBytes20();
        result.recipient = address(uint160(recipient));
    }
}
