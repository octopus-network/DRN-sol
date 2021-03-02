
const EthLocker = artifacts.require('./EthLocker.sol');
const RelayRegistry = artifacts.require('./RelayRegistry.sol');
const NearRelayDispatcher = artifacts.require('./NearRelayDispatcher.sol');

module.exports = async function (deployer, network, accounts) {
  // if (network === 'test') {
  //   const nearProverAddr = '0x...'
  //   const nearBridgeAddr = '0x...'

  //   const lReserveRatio = 40 * 100; // 40%
  //   const lRewardsRatio = 100 * 100; // 100%
  //   await deployer.deploy(EthLocker, lReserveRatio, lRewardsRatio);
  //   const ethLocker = await EthLocker.deployed();

  //   const rRelayerNumLimit = 12; // 12 relayers
  //   const rFreezingPeriod = 6500 * 2; // About 2 days
  //   const rRewardsRatio = 2;
  //   const rMinScoreRatio = 30; // 30%
  //   await deployer.deploy(RelayRegistry, rRelayerNumLimit, rFreezingPeriod, rRewardsRatio, rMinScoreRatio);
  //   const relayRegistry = await RelayRegistry.deployed();

  //   const nRainbowDao = Buffer.from('rainbowdao', 'utf-8');
  //   const nClaimPeriod = 6500 * 7; // About 7 days
  //   await deployer.deploy(NearRelayDispatcher, nearProverAddr, nRainbowDao, nClaimPeriod);
  //   const nearRelayDispatcher = await NearRelayDispatcher.deployed();

  //   await nearRelayDispatcher.setRelativeContracts(
  //     nearBridgeAddr,
  //     ethLocker.address,
  //     relayRegistry.address
  //   );

  //   await ethLocker.setDispatcher(nearRelayDispatcher.address);
  //   await relayRegistry.setDispatcher(nearRelayDispatcher.address);
  // }
};