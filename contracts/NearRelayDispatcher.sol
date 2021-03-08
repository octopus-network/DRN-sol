// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.4.22 <0.9.0;

import {INearBridge} from './interfaces/INearBridge.sol';
import {IEthLocker} from './interfaces/IEthLocker.sol';
import {IRelayRegistry} from './interfaces/IRelayRegistry.sol';
import 'rainbow-bridge-sol/nearprover/contracts/INearProver.sol';
import 'rainbow-bridge-sol/nearbridge/contracts/NearDecoder.sol';
import 'rainbow-bridge-sol/nearbridge/contracts/Borsh.sol';
import 'rainbow-bridge-sol/nearprover/contracts/ProofDecoder.sol';

contract NearRelayDispatcher {
    using Borsh for Borsh.Data;
    using NearDecoder for Borsh.Data;
    using ProofDecoder for Borsh.Data;

    event RelayLog(bytes32 indexed hash, uint64 height, address relayer, uint64 score);
    event RewardsClaimed();

    INearProver public prover;
    bytes public nearRainbowDao;

    INearBridge public nearBridge;
    IEthLocker public ethLocker;
    IRelayRegistry public relayRegistry;

    uint256 scoringStartAt;
    uint256 public claimPeriod;
    uint256 public fairGasPrice;

    mapping(bytes32 => uint256) public commitAtByNearHash;
    mapping(uint256 => uint64) public totalScore;
    mapping(uint256 => mapping(address => uint64)) public scoreOf;
    mapping(bytes32 => bool) public usedEvents;

    uint64 HIGH_SCORE = 50000;
    uint64 MEDIUM_SCORE = 40000;
    uint64 LOW_SCORE = 20000;

    constructor(
        INearProver defaultProver,
        bytes memory defaultNearRainbowDao,
        uint256 defaultClaimPeriod
    ) public {
        prover = defaultProver;
        nearRainbowDao = defaultNearRainbowDao;
        claimPeriod = defaultClaimPeriod;
        scoringStartAt = block.number;
    }

    // It doesn't need to use SafeMath here.
    modifier shouldRefundGasFee() {
        uint256 gasLeftAtStart = gasleft();
        _;
        uint256 basicCostGas = 50000;
        uint256 gasUsed = gasleft() - gasLeftAtStart + basicCostGas;
        // Don't use tx.gasPrice, the gas price must be reasonable.
        uint256 fee = gasUsed * fairGasPrice;

        relayRegistry.refundGasFee(msg.sender, fee);
    }

    function initRelativeContracts(
        INearBridge _nearBridge,
        IEthLocker _ethLocker,
        IRelayRegistry _relayRegistry
    ) public {
        if (nearBridge == INearBridge(0)) {
            nearBridge = _nearBridge;
        }
        if (ethLocker == IEthLocker(0)) {
            ethLocker = _ethLocker;
        }
        if (relayRegistry == IRelayRegistry(0)) {
            relayRegistry = _relayRegistry;
        }
    }

    function relayLightClientBlock(bytes memory data) public {
        Borsh.Data memory borshData = Borsh.from(data);
        // Skip 2 bytes32 params.
        borshData.offset += 64;
        bytes32 hash = borshData.peekSha256(208);
        uint64 height = borshData.decodeU64();
        uint256 commitAt = commitAtByNearHash[hash];
        if (commitAt == 0) {
            if (nearBridge.addLightClientBlock(data)) {
                commitAtByNearHash[hash] = block.number;
                _addScore(hash, height, msg.sender, HIGH_SCORE);
            }
        } else if (commitAt < 5) {
            _addScore(hash, height, msg.sender, MEDIUM_SCORE);
            // Every 2000 blocks there is a chance to update fairGasPrice
            if (block.number % 2000 < 10) {
                fairGasPrice = tx.gasprice;
            }
        } else if (commitAt < 30) {
            _addScore(hash, height, msg.sender, LOW_SCORE);
        }
    }

    function claimRewards() public shouldRefundGasFee {
        require(block.number - scoringStartAt > claimPeriod, 'Should wait');
        ethLocker.transferRewards(address(relayRegistry));
        relayRegistry.distributeRewards();
        scoringStartAt = block.number;
        emit RewardsClaimed();
    }

    // TODO
    function relayCommandFromDao(bytes calldata data, uint64 proofBlockHeight) public shouldRefundGasFee {
        ProofDecoder.ExecutionStatus memory status = _useProof(data, proofBlockHeight);
        Borsh.Data memory borshResult = Borsh.from(status.successValue);
        uint8 command = borshResult.decodeU8();
        require(command < 13 && command > 0, 'Command should be < 13 and > 0');

        // Start from 1 not 0, since the default uint is 0.
        // For Locker
        if (command == 1) {
            ethLocker.setRewardsRatio(borshResult.decodeU16());
        } else if (command == 2) {
            ethLocker.setMinHarvest(borshResult.decodeU16());
        } else if (command == 3) {
            ethLocker.depositToStrategy(_decodeAddress(borshResult), borshResult.decodeU256());
        } else if (command == 4) {
            ethLocker.depositAllToStrategy(_decodeAddress(borshResult));
        } else if (command == 5) {
            ethLocker.withdrawFromStrategy(_decodeAddress(borshResult), borshResult.decodeU256());
        } else if (command == 6) {
            ethLocker.withdrawAllFromStrategy(_decodeAddress(borshResult));
        } else if (command == 7) {
            ethLocker.setRewardsRatio(borshResult.decodeU16());
        } else if (command == 8) {
            ethLocker.harvest(_decodeAddress(borshResult));
        } else if (command == 9) {
            ethLocker.harvestAll();
        }
        // For Registry
        else if (command == 10) {
            relayRegistry.setRewardsRatio(borshResult.decodeU16());
        } else if (command == 11) {
            relayRegistry.setFreezingPeriod(borshResult.decodeU16());
        }
    }

    // It doesn't need to use SafeMath here.
    function _addScore(
        bytes32 hash,
        uint64 height,
        address targetAddr,
        uint64 score
    ) private {
        require(relayRegistry.isRelayer(targetAddr), 'Must be a relayer.');
        scoreOf[scoringStartAt][targetAddr] += score;
        totalScore[scoringStartAt] += score;
        emit RelayLog(hash, height, targetAddr, score);
    }

    function _useProof(bytes memory proofData, uint64 proofBlockHeight)
        internal
        returns (ProofDecoder.ExecutionStatus memory result)
    {
        require(prover.proveOutcome(proofData, proofBlockHeight), 'Proof should be valid');

        // Unpack the proof and extract the execution outcome.
        Borsh.Data memory borshData = Borsh.from(proofData);
        ProofDecoder.FullOutcomeProof memory fullOutcomeProof = borshData.decodeFullOutcomeProof();
        require(borshData.finished(), 'Argument should be exact borsh serialization');

        bytes32 receiptId = fullOutcomeProof.outcome_proof.outcome_with_id.outcome.receipt_ids[0];
        require(!usedEvents[receiptId], 'The command event cannot be reused');
        usedEvents[receiptId] = true;

        require(
            keccak256(fullOutcomeProof.outcome_proof.outcome_with_id.outcome.executor_id) == keccak256(nearRainbowDao),
            'Can only execute commands from the linked RainbowDao from near blockchain.'
        );

        result = fullOutcomeProof.outcome_proof.outcome_with_id.outcome.status;
        require(!result.failed, 'Cannot use failed execution outcome for executing the commands.');
        require(!result.unknown, 'Cannot use unknown execution outcome for executing the commands.');
    }

    function _decodeAddress(Borsh.Data memory data) internal pure returns (address) {
        bytes20 addressData = data.decodeBytes20();
        return address(uint160(addressData));
    }
}
