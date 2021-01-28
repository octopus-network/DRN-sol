// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

interface IEthLocker {
    function lockEth(uint256 amount, string memory accountId) external;

    function unlockToken(bytes memory proofData, uint64 proofBlockHeight) external;

    function burnResult(bytes memory proofData, uint64 proofBlockHeight) external view returns (address);

    // In case of loss
    function deposit() external payable;

    // For investments
    function setReserveRatio(uint16 ratio) external;

    function depositToStrategy(address strategyAddr, uint256 amount) external;

    function withdrawFromStrategy(address strategyAddr, uint256 amount) external;

    function withdrawAllFromStrategy(address strategyAddr, uint256 amount) external;

    // Rewards
    function setDividendRatio(uint16 ratio) external;

    function transferDividend(address strategyAddr) external;
}
