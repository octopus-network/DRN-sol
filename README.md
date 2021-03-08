# DRN-sol

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

DRN-sol is a set of Ethereum Smart Contracts that use idle funds in the locker to carry out risk-free financial management and to motivate relayers with income.

## Structure

![Structure](./imgs/structure.png)

## Usage flow

### RelayRegistry.sol

#### Registration process

1. Anyone can register as a relayer by sending `relayRegistry.register()` with eth that `stakingRequired`.
2. If relayerList reaches the `relayerLengthLimit`, the registrant will be listed in the candidates, or he will be one of relayers.
3. Candidates can invoke `activate()` to become a relayer when they find the `relayerList.length` is less than `relayerLengthLimit`.

#### Work process

Everytime a relayer invokes `claimRewards()` in NearRelayDispatcher.sol, the `distributeRewards()` will be used. It will count all their contributions in the past period of time, and therefore determine the amount of rewards distributed and whether to slash.

#### Quit process

1. If a candidate invokes `quit()` , his staking assets will move to his balance, so he can `withdraw(uint256)` or `withdrawAll()`.
2. If a relayer invokes `quit()` , he will be delisted immediately, but his staking assets will be frozen for `freezingPeriod`. If he did'nt be slashed in that period, then he can invoke `unfreezingToBalance()` to move the staking assets to his balance.
3. Everyone can `withdraw(uint256)` or `withdrawAll()`  their balance.



## Testing

```
cd DRN-sol
yarn
truffle test
```
