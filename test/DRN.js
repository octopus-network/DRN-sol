
const InvestmentStrategyMock = artifacts.require('./test/InvestmentStrategyMock.sol');
const NearProverMock = artifacts.require('./test/NearProverMock.sol');
const NearBridgeMock = artifacts.require('./test/NearBridgeMock.sol');

const EthLocker = artifacts.require('./EthLocker.sol');
const NearRelayDispatcher = artifacts.require('./NearRelayDispatcher.sol');
const RelayRegistry = artifacts.require('./RelayRegistry.sol');

const { borshify, serialize } = require('rainbow-bridge-lib/rainbow/borsh')
const { borshifyOutcomeProof } = require('rainbow-bridge-lib/rainbow/borshify-proof');
const truffleAssert = require('truffle-assertions');
const { constants: { ZERO_ADDRESS } } = require('@openzeppelin/test-helpers');

const { toWei, fromWei, hexToBytes, randomHex } = web3.utils;

const commandsMap = {
  // locker
  setReserveRatio: 1,
  setMinHarvest: 2,
  depositToStrategy: 3,
  depositAllToStrategy: 4,
  withdrawFromStrategy: 5,
  withdrawAllFromStrategy: 6,
  setRewardsRatio: 7,
  harvest: 8,
  harvestAll: 9,

  // relayRegistry
  setRewardsRatio: 10,
  setFreezingPeriod: 11
}

const HIGH_SCORE = 50000;
const MEDIUM_SCORE = 40000;
const LOW_SCORE = 20000;
const ROLE_RELAYER = 1;
const ROLE_CANDIDATE = 2;

const SCHEMA = {
  'depositAllToStrategy': {
    kind: 'struct', fields: [
      ['command', 'u8'],
      ['strategy', [20]],
    ]
  },
  'harvestAll': {
    kind: 'struct', fields: [
      ['command', 'u8'],
    ]
  },
};

contract('DRN', function ([_, addr1, addr2]) {
  let strategy;
  let nearProver;
  let nearBridge;
  let ethLocker;
  let relayRegistry;
  let dispatcher;

  before(async () => {
    strategy = await InvestmentStrategyMock.new();
    nearProver = await NearProverMock.new();
    nearBridge = await NearBridgeMock.new();

    const lReserveRatio = 40 * 100; // 40%
    const lRewardsRatio = 100 * 100; // 100%
    ethLocker = await EthLocker.new(lReserveRatio, lRewardsRatio);

    const rStakingRequired = toWei('5', 'ether'); // 5eth required for staking
    const rRelayerNumLimit = 12; // 12 relayers
    const rFreezingPeriod = 6500 * 2; // About 2 days
    const rRewardsRatio = 2;
    const rMinScoreRatio = 30; // 30%
    relayRegistry = await RelayRegistry.new(rStakingRequired, rFreezingPeriod, rRelayerNumLimit, rRewardsRatio, rMinScoreRatio);

    const nRainbowDao = Buffer.from('rainbowdao', 'utf-8');
    const nClaimPeriod = 6500 * 7; // About 7 days
    dispatcher = await NearRelayDispatcher.new(nearProver.address, nRainbowDao, nClaimPeriod);

    await ethLocker.setDispatcher(dispatcher.address);
    await relayRegistry.setDispatcher(dispatcher.address);
  });

  it('initRelativeContracts on dispatcher', async function () {
    const prevNearBridgeAddr = await dispatcher.nearBridge.call();
    const prevEthLockerAddr = await dispatcher.ethLocker.call();
    const prevRegistryAddr = await dispatcher.relayRegistry.call();
    assert.equal(prevNearBridgeAddr, ZERO_ADDRESS);
    assert.equal(prevEthLockerAddr, ZERO_ADDRESS);
    assert.equal(prevRegistryAddr, ZERO_ADDRESS);

    await dispatcher.initRelativeContracts(
      nearBridge.address,
      ethLocker.address,
      relayRegistry.address
    );

    const currNearBridgeAddr = await dispatcher.nearBridge.call();
    const currEthLockerAddr = await dispatcher.ethLocker.call();
    const currRegistryAddr = await dispatcher.relayRegistry.call();
    assert.equal(currNearBridgeAddr, nearBridge.address);
    assert.equal(currEthLockerAddr, ethLocker.address);
    assert.equal(currRegistryAddr, relayRegistry.address);
  });

  it('register as a relayer', async function () {
    console.log('addr1', addr1);
    const tx = await relayRegistry.register({ from: addr1, value: toWei('5', 'ether') });
    truffleAssert.eventEmitted(tx, 'Listed', (event) => {
      return event.relayer === addr1 && Number(event.role) === ROLE_RELAYER;
    });
  });

  it('relayBlock', async function () {
    const block = borshify(require('./block_template.json'));
    const tx = await dispatcher.relayLightClientBlock(block, { from: addr1 });
    truffleAssert.eventEmitted(tx, 'RelayLog', (event) => {
      return Number(event.height) === 9605 && event.relayer === addr1 && Number(event.score) === HIGH_SCORE;
    });
  });

  it('lock eth', async function () {
    const lockedAmount = toWei('20', 'ether');
    const accountId = 'test.testnet';
    const tx = await ethLocker.lockEth('test.testnet', { from: addr1, value: lockedAmount });
    truffleAssert.eventEmitted(tx, 'Locked', (event) => {
      return event.sender === addr1 && event.amount.toString() === lockedAmount && event.accountId === accountId;
    });
  });

  it('invest all', async function () {
    const reserve = await ethLocker.reserve.call();
    assert.equal(fromWei(reserve), 8)

    // deposit to strategy
    await relayCommand(dispatcher, 'depositAllToStrategy', { strategy: hexToBytes(strategy.address) });
    const strategyBalance = await strategy.balance.call(ethLocker.address);
    assert.equal(fromWei(strategyBalance), 12);
  });

  it('harvest all', async function () {
    const profit = toWei('0.06', 'ether');
    await strategy.generateProfit(ethLocker.address, { from: _, value: profit });
    const prevSBalance = await strategy.balance.call(ethLocker.address);
    assert.equal(fromWei(prevSBalance), 12.06);

    await relayCommand(dispatcher, 'harvestAll', {});
    const availableProfit = await strategy.availableProfit.call(ethLocker.address);
    const currSBalance = await strategy.balance.call(ethLocker.address);
    assert.equal(fromWei(availableProfit), 0);
    assert.equal(fromWei(currSBalance), 12);
  });

});

async function relayCommand(dispatcher, name, params) {
  const proof = require(`./proof_template_${commandsMap[name]}.json`);
  proof.outcome_proof.outcome.status.SuccessValue = serialize(SCHEMA, name, {
    command: commandsMap[name],
    ...params
  }).toString('base64');

  return await dispatcher.relayCommandFromDao(borshifyOutcomeProof(proof), 1100);
}