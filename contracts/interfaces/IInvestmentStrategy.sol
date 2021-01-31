// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.4.22 <0.9.0;

interface InvestmentStrategy {
    function balance() external view returns (uint256);

    function availableProfit() external view returns (uint256);

    function deposit(uint256) external;

    function depositAll() external;

    function withdraw(uint256) external;

    function harvest() external;

    function withdrawAll() external;
}
