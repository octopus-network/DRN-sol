
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

const bs58 = require('bs58');
const Promise = require('bluebird')
const crypto = Promise.promisifyAll(require('crypto'))
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

const RAINBOW_DAO = 'rainbowdao'
const NEAR_ETH_FACTORY = 'neareth'

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
  'Unlock': {
    kind: 'struct', fields: [
      ['amount', 'u128'],
      ['recipient', [20]],
    ]
  }
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

    const lNearEthFactory = Buffer.from(NEAR_ETH_FACTORY, 'utf-8');
    const lReserveRatio = 40 * 100; // 40%
    const lMinReserveRatio = 18 * 100; // 18%
    const lRewardsRatio = 100 * 100; // 100%
    ethLocker = await EthLocker.new(lNearEthFactory, nearProver.address, lReserveRatio, lMinReserveRatio, lRewardsRatio);

    const rStakingRequired = toWei('5', 'ether'); // 5eth required for staking
    const rrelayerLengthLimit = 12; // 12 relayers
    const rFreezingPeriod = 6500 * 2; // About 2 days
    const rRewardsRatio = 2;
    const rMinScoreRatio = 30; // 30%
    relayRegistry = await RelayRegistry.new(rStakingRequired, rFreezingPeriod, rrelayerLengthLimit, rRewardsRatio, rMinScoreRatio);

    const nRainbowDao = Buffer.from(RAINBOW_DAO, 'utf-8');
    const nClaimPeriod = 6500 * 7; // About 7 days
    dispatcher = await NearRelayDispatcher.new(nearProver.address, nRainbowDao, nClaimPeriod);

    await ethLocker.initDispatcher(dispatcher.address);
    await relayRegistry.initDispatcher(dispatcher.address);
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
    const currStrategyBalance = await strategy.balance.call(ethLocker.address);
    assert.equal(fromWei(availableProfit), 0);
    assert.equal(fromWei(currStrategyBalance), 12);

    const currLockerBalance = await web3.eth.getBalance(ethLocker.address);
    assert.equal(fromWei(currLockerBalance), 8 + 0.06);
  });

  it('unlock', async function () {
    const unlockAmount = 18;
    const currLockerBalance = Number(fromWei(await web3.eth.getBalance(ethLocker.address)));
    const lMinReserveRatio = 0.18;
    const lockedEth = Number(fromWei(await ethLocker.lockedEth.call()));
    const recipient = addr1;

    const tx = await unlockEth(ethLocker, {
      amount: toWei(unlockAmount.toString(), 'ether'),
      recipient: hexToBytes(recipient),
    });
    truffleAssert.eventEmitted(tx, 'Unlocked', (event) => {
      return fromWei(event.amount) === '18' && event.recipient === recipient;
    });


    const safeBalance = currLockerBalance - lMinReserveRatio * (lockedEth - unlockAmount);
    const debt = 18 - safeBalance;
    truffleAssert.eventEmitted(tx, 'DebtCreated', (event) => {
      return event.creditor === recipient && fromWei(event.debt) === debt.toString() && fromWei(event.totalDebt) === debt.toString();
    });
  });

});

async function randomProof(executorId, schemaName, paramsObj) {
  const proof = require(`./proof_template.json`);
  const randomBytes = await crypto.randomBytesAsync(32);
  const randomReceiptId = bs58.encode(randomBytes);
  proof.outcome_proof.outcome.receipt_ids[0] = randomReceiptId;
  proof.outcome_proof.outcome.executor_id = executorId;
  proof.outcome_proof.outcome.status.SuccessValue = serialize(SCHEMA, schemaName, paramsObj).toString('base64');
  return borshifyOutcomeProof(proof);
}

async function relayCommand(dispatcher, commandName, paramsObj) {
  const proof = await randomProof(RAINBOW_DAO, commandName, {
    command: commandsMap[commandName],
    ...paramsObj
  });
  return await dispatcher.relayCommandFromDao(proof, 1100);
}

async function unlockEth(ethLocker, paramsObj) {
  const proof = await randomProof(NEAR_ETH_FACTORY, 'Unlock', paramsObj)
  return await ethLocker.unlockEth(proof, 1100);
}