// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

contract RelayRegistry {
    event Registered(address indexed relayer);
    event Listed(address indexed relayer);
    event Quit(address indexed relayer);
    event Slashed(address indexed relayer);
    event DeListed(address indexed relayer);

    address public dispatcherAddr;

    uint256 public vaultBalance;
    uint256 public stakingAmount;
    address[32] public waitingList;
    address[7] public relayerList;

    mapping(address => bool) isRelayer;
    mapping(address => bool) isWaiting;
    mapping(address => uint256) public balanceOf;

    constructor() public {}

    function register() public payable {}

    function activate() public {}

    function quit() public {}

    function deposit() public payable {}

    function withdraw(uint256) public {}

    function withdrawAll() public {}

    function distributeRewards() public {}
}
