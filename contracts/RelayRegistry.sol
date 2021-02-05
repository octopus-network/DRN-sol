// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.4.22 <0.9.0;

import '@openzeppelin/contracts/math/SafeMath.sol';
import './ArrayUtils.sol';
import {INearRelayDispatcher} from './interfaces/INearRelayDispatcher.sol';

contract RelayRegistry {
    using SafeMath for uint256;
    using ArrayUtils for address[];

    // type 0 means relayer list, type 1 means candidate list.
    event Listed(address indexed relayer, uint8 listType);
    event DeListed(address indexed relayer, uint8 listType);
    event Slashed(address indexed relayer);

    address public dispatcherAddr;

    uint256 public stakingRequired;
    uint256 public freezingPeriod;
    address[] public relayerList;
    uint256 public relayerNumLimit;
    address[] public candidateList;
    uint256 public candidateNumLimit;
    // 10000 for 100.00%
    uint16 public rewardsRatio;
    uint16 public minScoreRatio;

    mapping(address => bool) isRelayer;
    mapping(address => bool) isCandidate;
    mapping(address => uint256) public balanceOf;
    mapping(address => uint256) public frozenHeightOf;

    constructor(
        uint256 defaultFreezingPeriod,
        uint16 defaultRewardsRatio,
        uint16 defaultMinScoreRatio
    ) public {
        freezingPeriod = defaultFreezingPeriod;
        rewardsRatio = defaultRewardsRatio;
        minScoreRatio = defaultMinScoreRatio;
    }

    modifier onlyRegistered {
        require(isRelayer[msg.sender] || isCandidate[msg.sender], 'not registered');
        _;
    }

    modifier onlyNewUser {
        require(isRelayer[msg.sender] && isCandidate[msg.sender], 'Already registered');
        _;
    }

    modifier onlyRelayer {
        require(isRelayer[msg.sender] && !isCandidate[msg.sender], 'Not a relayer');
        _;
    }

    modifier onlyCandidate {
        require(isCandidate[msg.sender] && !isRelayer[msg.sender], 'Not a candidate');
        _;
    }

    modifier onlyDispatcher {
        require(msg.sender == dispatcherAddr, 'Not dispatcher');
        _;
    }

    function setDispatcher(address targetAddr) public {
        if (dispatcherAddr == address(0)) {
            dispatcherAddr = targetAddr;
        }
    }

    function deposit() public payable {}

    function register() public payable onlyNewUser {
        require(msg.value == stakingRequired, 'staking amount not correct');
        if (relayerList.length < relayerNumLimit) {
            _addRelayer(msg.sender);
        } else {
            require(candidateList.length < candidateNumLimit, 'Candidate list full');
            _addCandidate(msg.sender);
        }
    }

    function activate() public onlyCandidate {
        address _sender = msg.sender;
        require(relayerList.length < relayerNumLimit, 'Relayer list full');
        _addRelayer(_sender);
        _removeCandidate(_sender);
    }

    function quit() public onlyRegistered {
        if (isRelayer[msg.sender]) {
            frozenHeightOf[msg.sender] = block.number;
            _removeRelayer(msg.sender);
        } else {
            balanceOf[msg.sender] = balanceOf[msg.sender].add(stakingRequired);
            _removeCandidate(msg.sender);
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

    function withdrawAll() public payable {
        msg.sender.transfer(balanceOf[msg.sender]);
    }

    function setRewardsRatio(uint16 value) public onlyDispatcher {
        rewardsRatio = value;
    }

    function distributeRewards() public onlyDispatcher {
        INearRelayDispatcher dispatcher = INearRelayDispatcher(dispatcherAddr);
        uint256 totalRewards = address(this).balance.mul(rewardsRatio);
        uint32 totalScore = dispatcher.totalScore();
        for (uint256 i = 0; i < relayerList.length; i++) {
            address relayerAddr = relayerList[i];
            uint32 score = dispatcher.scoreOf(relayerAddr);
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

    function _slash(address targetAddr) private {
        frozenHeightOf[targetAddr] = 0;
        emit Slashed(targetAddr);
    }

    function refundGasFee(address payable sender, uint256 amount) public onlyDispatcher {
        sender.transfer(amount);
    }

    function _addRelayer(address tragetAddr) private {
        relayerList.push(tragetAddr);
        isRelayer[tragetAddr] = true;
        emit Listed(tragetAddr, 0);
    }

    function _removeRelayer(address tragetAddr) private {
        relayerList.removeByFind(tragetAddr);
        isRelayer[tragetAddr] = false;
        emit DeListed(tragetAddr, 0);
    }

    function _addCandidate(address tragetAddr) private {
        candidateList.push(tragetAddr);
        isCandidate[tragetAddr] = true;
        emit Listed(tragetAddr, 1);
    }

    function _removeCandidate(address tragetAddr) private {
        candidateList.removeByFind(tragetAddr);
        isCandidate[tragetAddr] = false;
        emit DeListed(tragetAddr, 1);
    }

    fallback() external payable {
        revert();
    }
}
