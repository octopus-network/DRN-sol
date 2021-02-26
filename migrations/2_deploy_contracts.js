const NearProverMock = artifacts.require('./NearProverMock.sol');
const NearBridgeMock = artifacts.require('./NearBridgeMock.sol');

const EthLocker = artifacts.require('./EthLocker.sol');
const RelayRegistry = artifacts.require('./RelayRegistry.sol');
const NearRelayDispatcher = artifacts.require('./NearRelayDispatcher.sol');

module.exports = async function (deployer, network, accounts) {
  if (network === 'test') {
    const nearProver = await NearProverMock.deploy(NearProverMock);
    const nearBridge = await NearBridgeMock.deploy(NearProverMock);
    
    const lReserveRatio = 40 * 100; // 40%
    const lRewardsRatio = 100 * 100; // 100%
    const ethLocker = await deployer.deploy(EthLocker, lReserveRatio, lRewardsRatio);
    
    const rFreezingPeriod = 6500 * 2; // About 2 days
    const rRewardsRatio = 2;
    const rMinScoreRatio = 30; // 30%
    const relayRegistry = await deployer.deploy(RelayRegistry, rFreezingPeriod, rRewardsRatio, rMinScoreRatio);
    
    const nRainbowDao = 'rainbowdao';
    const nClaimPeriod = 6500 * 7; // About 7 days
    const nearRelayDispatcher = await deployer.deploy(NearRelayDispatcher, nearProver.address, nRainbowDao, nClaimPeriod);
    await nearRelayDispatcher.setRelativeContracts(
      nearBridge.address,
      ethLocker.address,
      relayRegistry.address
    );
    
    await ethLocker.setDispatcher(nearRelayDispatcher.address);
    await relayRegistry.setDispatcher(nearRelayDispatcher.address);
  }
};