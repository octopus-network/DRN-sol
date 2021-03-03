// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.4.22 <0.9.0;

interface IInvestmentStrategy {
    function capital(address) external view returns (uint256);

    function availableProfit(address) external view returns (uint256);

    function balance(address) external view returns (uint256);

    function deposit() external payable;

    function withdraw(uint256) external;

    function harvest() external payable;

    function withdrawAll() external;
}
