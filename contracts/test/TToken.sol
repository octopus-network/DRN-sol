// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.4.22 <0.9.0;
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract TToken is ERC20 {
    constructor() public ERC20('TToken', 'TT') {
        _mint(msg.sender, 1000000000);
    }

    function mint(address beneficiary, uint256 amount) public {
        _mint(beneficiary, amount);
    }
}
