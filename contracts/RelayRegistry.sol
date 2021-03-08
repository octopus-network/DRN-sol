// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.4.22 <0.9.0;

import '@openzeppelin/contracts/math/SafeMath.sol';
import './ArrayUtils.sol';
import {INearRelayDispatcher} from './interfaces/INearRelayDispatcher.sol';

contract RelayRegistry {
    using SafeMath for uint256;
    using ArrayUtils for address[];

    // type 1 means relayer list, type 2 means candidate list.
    event Listed(address indexed relayer, uint8 role);
    event DeListed(address indexed relayer, uint8 role);
    event Slashed(address indexed relayer);

    address public dispatcherAddr;
    uint256 public stakingRequired;
    uint256 public freezingPeriod;
    address[] public relayerList;
    uint256 public relayerLengthLimit;
    // 10000 for 100.00%
    uint16 public rewardsRatio;
    uint16 public minScoreRatio;

    mapping(address => uint8) roleMap;
    mapping(address => uint256) public balanceOf;
    mapping(address => uint256) public frozenHeightOf;

    uint8 ROLE_RELAYER = 1;
    uint8 ROLE_CANDIDATE = 2;

    constructor(
        uint256 defaultStakingRequired,
        uint256 defaultrelayerLengthLimit,
        uint256 defaultFreezingPeriod,
        uint16 defaultRewardsRatio,
        uint16 defaultMinScoreRatio
    ) public {
        stakingRequired = defaultStakingRequired;
        relayerLengthLimit = defaultrelayerLengthLimit;
        freezingPeriod = defaultFreezingPeriod;
        rewardsRatio = defaultRewardsRatio;
        minScoreRatio = defaultMinScoreRatio;
    }

    modifier onlyRegistered {
        require(roleMap[msg.sender] > 0, 'not registered');
        _;
    }

    modifier onlyNewUser {
        require(roleMap[msg.sender] == 0, 'Already registered');
        _;
    }

    modifier onlyRelayer {
        require(isRelayer(msg.sender), 'Not a relayer');
        _;
    }

    modifier onlyCandidate {
        require(isCandidate(msg.sender), 'Not a candidate');
        _;
    }

    modifier onlyDispatcher {
        require(msg.sender == dispatcherAddr, 'Not dispatcher');
        _;
    }

    function isRelayer(address targetAddr) public view returns (bool) {
        return roleMap[targetAddr] == ROLE_RELAYER;
    }

    function isCandidate(address targetAddr) public view returns (bool) {
        return roleMap[targetAddr] == ROLE_CANDIDATE;
    }

    function initDispatcher(address targetAddr) public {
        if (dispatcherAddr == address(0)) {
            dispatcherAddr = targetAddr;
        }
    }

    function deposit() public payable {}

    function register() public payable onlyNewUser {
        require(msg.value == stakingRequired, 'staking amount not correct');
        if (!_addRelayer(msg.sender)) {
            _addCandidate(msg.sender);
        }
    }

    function activate() public onlyCandidate {
        address _sender = msg.sender;
        require(_addRelayer(_sender), 'Relayer list full');
    }

    function quit() public onlyRegistered {
        if (roleMap[msg.sender] == ROLE_RELAYER) {
            frozenHeightOf[msg.sender] = block.number;
            _removeRelayer(msg.sender);
        } else {
            // candidate
            balanceOf[msg.sender] = balanceOf[msg.sender].add(stakingRequired);
            _delist(msg.sender);
        }
    }

    function unfreezingToBalance() public {
        address _sender = msg.sender;
        uint256 frozenHeight = frozenHeightOf[_sender];
        require(frozenHeight > 0, 'No frozen balance');
        require(block.number.sub(frozenHeight) > freezingPeriod, 'Should wait');
        balanceOf[msg.sender] = balanceOf[msg.sender].add(stakingRequired);
    }

    function withdraw(uint256 amount) public {
        require(amount <= balanceOf[msg.sender], 'Insufficient balance');
        msg.sender.transfer(amount);
    }

    function withdrawAll() public {
        msg.sender.transfer(balanceOf[msg.sender]);
    }

    function setStakingRequired(uint256 value) public onlyDispatcher {
        stakingRequired = value;
    }

    function setrelayerLengthLimit(uint256 value) public onlyDispatcher {
        relayerLengthLimit = value;
    }

    function setRewardsRatio(uint16 value) public onlyDispatcher {
        rewardsRatio = value;
    }

    function setFreezingPeriod(uint256 value) public onlyDispatcher {
        freezingPeriod = value;
    }

    function distributeRewards() public onlyDispatcher {
        INearRelayDispatcher dispatcher = INearRelayDispatcher(dispatcherAddr);
        uint256 totalRewards = address(this).balance.mul(rewardsRatio);
        uint256 scoringStartAt = dispatcher.scoringStartAt();
        uint64 totalScore = dispatcher.totalScore(scoringStartAt);
        for (uint256 i = 0; i < relayerList.length; i++) {
            address relayerAddr = relayerList[i];
            uint64 score = dispatcher.scoreOf(scoringStartAt, relayerAddr);
            uint256 averageScore = uint256(totalScore).div(relayerList.length);
            uint256 minScore = averageScore.mul(minScoreRatio).div(10000);
            if (uint256(score).div(totalScore) < minScore) {
                _slash(relayerAddr);
                _removeRelayer(relayerAddr);
            } else {
                balanceOf[relayerAddr] = totalRewards.mul(score).div(totalScore);
            }
        }
    }

    function refundGasFee(address payable sender, uint256 amount) public onlyDispatcher {
        sender.transfer(amount);
    }

    function _slash(address targetAddr) private {
        frozenHeightOf[targetAddr] = 0;
        emit Slashed(targetAddr);
    }

    function _addRelayer(address tragetAddr) private returns (bool) {
        if (relayerList.length < relayerLengthLimit) {
            relayerList.push(tragetAddr);
            roleMap[tragetAddr] = ROLE_RELAYER;
            emit Listed(tragetAddr, ROLE_RELAYER);
            return true;
        } else {
            return false;
        }
    }

    function _removeRelayer(address tragetAddr) private {
        relayerList.removeByFind(tragetAddr);
        _delist(tragetAddr);
    }

    function _addCandidate(address tragetAddr) private {
        roleMap[tragetAddr] = ROLE_CANDIDATE;
        emit Listed(tragetAddr, ROLE_CANDIDATE);
    }

    function _delist(address tragetAddr) private {
        emit DeListed(tragetAddr, roleMap[tragetAddr]);
        roleMap[tragetAddr] = 0;
    }
}
