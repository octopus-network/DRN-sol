// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.4.22 <0.9.0;

contract InvestmentStrategyMock {
    event Deposited(address indexed investor, uint256 amount);

    mapping(address => uint256) public capital;
    mapping(address => uint256) public availableProfit;

    function balance(address targetAddr) public view returns (uint256) {
        return capital[targetAddr] + availableProfit[targetAddr];
    }

    function deposit() public payable {
        capital[msg.sender] += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    function generateProfit(address targetAddr) public payable {
        availableProfit[targetAddr] += msg.value;
    }

    function withdraw(uint256 amount) public {
        require(amount <= balance(msg.sender), 'insufficient balance');
        msg.sender.transfer(amount);
        if (amount <= capital[msg.sender]) {
            capital[msg.sender] -= amount;
        } else {
            capital[msg.sender] = 0;
            availableProfit[msg.sender] = amount - capital[msg.sender];
        }
    }

    function harvest() public payable {
        msg.sender.transfer(availableProfit[msg.sender]);
        availableProfit[msg.sender] = 0;
    }

    function withdrawAll() public {
        msg.sender.transfer(balance(msg.sender));
        capital[msg.sender] = 0;
        availableProfit[msg.sender] = 0;
    }
}
