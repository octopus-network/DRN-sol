// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.4.22 <0.9.0;

import {INearBridge} from './interfaces/INearBridge.sol';
import {IEthLocker} from './interfaces/IEthLocker.sol';
import {IRelayRegistry} from './interfaces/IRelayRegistry.sol';
import 'rainbow-bridge-sol/nearprover/contracts/INearProver.sol';
import 'rainbow-bridge-sol/nearbridge/contracts/NearDecoder.sol';
import 'rainbow-bridge-sol/nearbridge/contracts/Borsh.sol';
import "rainbow-bridge-sol/nearprover/contracts/ProofDecoder.sol";

contract NearRelayDispatcher {
    using Borsh for Borsh.Data;
    using NearDecoder for Borsh.Data;
    using ProofDecoder for Borsh.Data;

    event RelayLog(bytes32 indexed hash, address relayer, uint32 score);
    event RewardsClaimed();

    INearProver public prover;
    bytes public nearRainbowDao;

    address public nearBridgeAddr;
    address public ethLockerAddr;
    address public relayRegistryAddr;

    uint32 totalScore;
    uint256 lastClaimAt;
    uint256 public claimPeriod;
    uint256 public reasonableGasPrice;

    mapping(bytes32 => uint256) public commitHeightByNearHash;
    mapping(address => uint32) public scoreOf;

    struct Command {
        uint8 flag;
        bytes paramsData;
    }

    constructor(
        INearProver defaultProver,
        bytes calldata defaultNearRainbowDao
        uint256 defaultClaimPeriod,
    ) public {
        prover = defaultProver;
        nearRainbowDao = defaultNearRainbowDao;
        claimPeriod = defaultClaimPeriod;
        lastClaimAt = block.number;
    }

    // It doesn't need to use SafeMath here.
    modifier shouldRefundGasFee() {
        uint256 gasLeftAtStart = gasleft();
        _;
        uint256 basicCostGas = 50000;
        uint256 gasUsed = gasleft() - gasLeftAtStart + basicCostGas;
        // Don't use tx.gasPrice, the gas price must be reasonable.
        uint256 fee = gasUsed * reasonableGasPrice;

        IRelayRegistry relayRegistry = IRelayRegistry(relayRegistryAddr);
        refundGasFee.refundGasFee(msg.sender, fee);
    }

    function setRelativeContracts(
        address nearBridge,
        address ethLocker,
        address relayRegistry
    ) public {
        if (nearBridgeAddr == address(0)) {
            nearBridgeAddr = nearBridge;
        }
        if (nearBridgeAddr == address(0)) {
            ethLockerAddr = ethLocker;
        }
        if (nearBridgeAddr == address(0)) {
            relayRegistryAddr = relayRegistry;
        }
    }

    function relayLightClientBlock(bytes calldata data) public {
        INearBridge nearBridge = INearBridge(nearBridgeAddr);
        Borsh.Data memory borshData = Borsh.from(data);
        // Skip 2 bytes32 params.
        borshData.offset += 64;
        bytes32 hash = borshData.peekSha256(208);
        uint256 commitHeight = commitHeightByNearHash[hash];
        if (commitHeight == 0) {
            if (nearBridge.addLightClientBlock(data)) {
                commitHeightByNearHash[hash] = block.number;
                _addScore(hash, msg.sender, 50000);
            }
        } else if (commitHeight < 5) {
            _addScore(hash, msg.sender, 40000);
            // Every 2000 blocks there is a chance to update reasonableGasPrice
            if (block.number % 2000 < 10) {
                reasonableGasPrice = tx.gasprice;
            }
        } else if (commitHeight < 30) {
            _addScore(hash, msg.sender, 20000);
        }
    }

    function claimRewards() public shouldRefundGasFee {
        require(block.number - lastClaimAt > claimPeriod, 'Should wait');
        IEthLocker ethLocker = IEthLocker(ethLockerAddr);
        IRelayRegistry relayRegistry = IRelayRegistry(relayRegistryAddr);
        ethLocker.transferRewards(relayRegistryAddr);
        relayRegistry.distributeRewards();
        emit RewardsClaimed();
    }

    // TODO
    function relayCommandFromDao(bytes calldata data, uint64 proofBlockHeight) public shouldRefundGasFee {
        Borsh.Data memory borshData = Borsh.from(data);
        ProofDecoder.ExecutionStatus memory status = _parseProof(proofData, proofBlockHeight);

        Borsh.Data memory borshResult = Borsh.from(status.successValue);
        command = borshResult.decodeU8();
        require(command < 13 && command > 0, 'Command should be < 13 and > 0');
        
        IEthLocker ethLocker = IEthLocker(ethLockerAddr);
        IRelayRegistry relayRegistry = IRelayRegistry(relayRegistryAddr);

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
            ethLocker.setRewardsRatio(_borshResult.decodeU16());
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
        address targetAddr,
        uint32 score
    ) private {
        scoreOf[targetAddr] += score;
        totalScore += score;
        emit RelayLog(hash, targetAddr, score);
    }

    function _parseProof(bytes memory proofData, uint64 proofBlockHeight)
        internal
        returns (ProofDecoder.ExecutionStatus memory result)
    {
        require(prover.proveOutcome(proofData, proofBlockHeight), 'Proof should be valid');

        // Unpack the proof and extract the execution outcome.
        Borsh.Data memory borshData = Borsh.from(proofData);
        ProofDecoder.FullOutcomeProof memory fullOutcomeProof = borshData.decodeFullOutcomeProof();
        require(borshData.finished(), 'Argument should be exact borsh serialization');

        bytes32 receiptId = fullOutcomeProof.outcome_proof.outcome_with_id.outcome.receipt_ids[0];
        require(!usedEvents_[receiptId], 'The command event cannot be reused');
        usedEvents_[receiptId] = true;

        require(
            keccak256(fullOutcomeProof.outcome_proof.outcome_with_id.outcome.executor_id) ==
                keccak256(nearRainbowDao),
            'Can only execute commands from the linked RainbowDao from near blockchain.'
        );

        result = fullOutcomeProof.outcome_proof.outcome_with_id.outcome.status;
        require(!result.failed, 'Cannot use failed execution outcome for executing the commands.');
        require(!result.unknown, 'Cannot use unknown execution outcome for executing the commands.');
    }

    function _decodeAddress(Borsh.Data memory data) internal pure returns(address) {
        bytes20 addressData = data.decodeBytes20();
        return address(uint160(addressData));
    }

}
