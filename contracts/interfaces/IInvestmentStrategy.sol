// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

interface InvestmentStrategy {
    function balance() external view returns (uint256);

    function deposit(uint256) external;

    function depositAll() external;

    function withdraw(uint256) external;

    function withdrawAll() external;
}
