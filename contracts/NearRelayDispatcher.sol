// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.4.22 <0.9.0;

import {INearBridge} from './interfaces/INearBridge.sol';
import {IEthLocker} from './interfaces/IEthLocker.sol';
import {IRelayRegistry} from './interfaces/IRelayRegistry.sol';
import 'rainbow-bridge-sol/nearbridge/contracts/NearDecoder.sol';
import 'rainbow-bridge-sol/nearbridge/contracts/Borsh.sol';

contract NearRelayDispatcher {
    using Borsh for Borsh.Data;
    using NearDecoder for Borsh.Data;

    event RelayLog(bytes32 indexed hash, address relayer, uint32 score);
    event RewardsClaimed();

    address public nearBridgeAddr;
    address public ethLockerAddr;
    address public relayRegistryAddr;

    uint32 totalScore;
    uint256 lastClaimAt;
    uint256 public claimPeriod;
    uint256 public reasonableGasPrice;

    mapping(bytes32 => uint256) public commitHeightByNearHash;
    mapping(address => uint32) public scoreOf;

    constructor(uint256 defaultClaimPeriod) public {
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
        Borsh.Data memory borsh = Borsh.from(data);
        bytes32 hash = borsh.peekSha256(208);
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

    function relayCommandFromDao(bytes calldata data) public shouldRefundGasFee {}

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
}
