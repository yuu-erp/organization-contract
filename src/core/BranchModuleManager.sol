// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {RoleHashes} from "./constants/RoleHashes.sol";

import {ISystemAccessControl} from "./interfaces/ISystemAccessControl.sol";
import {IOrganizationManager} from "./interfaces/IOrganizationManager.sol";
import {IModuleRegistry} from "../registry/interfaces/IModuleRegistry.sol";
import {IBranchModuleManager} from "./interfaces/IBranchModuleManager.sol";
import {IModuleFactory} from "./interfaces/IModuleFactory.sol";

import {BranchModuleManagerStorage} from "./storage/BranchModuleManagerStorage.sol";

interface IBranchStaffManagerInit {
    function initialize(uint48 _branchId, uint48 _orgId, address _organizationManager) external;
    function setBranchGovernanceManager(address _govManager) external;
    function setStaffMetadataRegistry(address _registry) external;
}

/**
 * @title BranchModuleManager
 * @dev Orchestrator chính: provision branch, deploy các dịch vụ dùng chung (StaffManager & GovernanceManager).
 */
contract BranchModuleManager is Initializable, UUPSUpgradeable, BranchModuleManagerStorage, IBranchModuleManager {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Khởi tạo contract.
     */
    function initialize(
        address accessControlAddress,
        address organizationManagerAddress,
        address moduleRegistryAddress,
        address staffManagerBeaconAddress
    ) external initializer {
        if (
            accessControlAddress == address(0) || organizationManagerAddress == address(0)
                || moduleRegistryAddress == address(0) || staffManagerBeaconAddress == address(0)
        ) {
            revert InvalidAddress();
        }

        accessControl = ISystemAccessControl(accessControlAddress);
        organizationManager = IOrganizationManager(organizationManagerAddress);
        moduleRegistry = IModuleRegistry(moduleRegistryAddress);
        staffManagerBeacon = staffManagerBeaconAddress;
    }

    // ====== Modifiers ======

    modifier onlyPlatformAdmin() {
        if (!accessControl.hasRole(RoleHashes.PLATFORM_ADMIN_ROLE, msg.sender)) {
            revert Unauthorized();
        }
        _;
    }

    // ====== Setters ======
    
    /**
     * @dev Cập nhật Beacon Governance và Registry Metadata tập trung.
     */
    function setGovernanceAndRegistry(address _govBeacon, address _metadataRegistry) external onlyPlatformAdmin {
        if (_govBeacon == address(0) || _metadataRegistry == address(0)) {
            revert InvalidAddress();
        }
        governanceBeacon = _govBeacon;
        staffMetadataRegistry = _metadataRegistry;
    }

    // ====== Core Functions ======

    /**
     * @dev Provision branch: deploy BranchStaffManager và BranchGovernanceManager.
     */
    function provisionBranch(uint48 branchId, uint48 orgId) external onlyPlatformAdmin {
        if (!organizationManager.branchExists(branchId)) {
            revert InvalidInput();
        }

        if (branchProvisioned[branchId]) {
            revert BranchAlreadyProvisioned();
        }

        if (governanceBeacon == address(0) || staffMetadataRegistry == address(0)) {
            revert InvalidInput(); // Yêu cầu cấu hình Beacon Gov và Registry trước
        }

        // 1. Deploy BranchStaffManager via Beacon Proxy
        address staffManager = address(
            new BeaconProxy(
                staffManagerBeacon,
                abi.encodeWithSignature(
                    "initialize(uint48,uint48,address)", branchId, orgId, address(organizationManager)
                )
            )
        );

        // 2. Deploy BranchGovernanceManager via Beacon Proxy
        address govManager = address(
            new BeaconProxy(
                governanceBeacon,
                abi.encodeWithSignature(
                    "initialize(uint48,uint48,address,address,address)",
                    branchId,
                    orgId,
                    address(organizationManager),
                    staffManager,
                    staffMetadataRegistry
                )
            )
        );

        // 3. Liên kết chéo
        IBranchStaffManagerInit(staffManager).setBranchGovernanceManager(govManager);
        IBranchStaffManagerInit(staffManager).setStaffMetadataRegistry(staffMetadataRegistry);

        // Lưu state
        branchStaffManagers[branchId] = staffManager;
        branchGovernanceManagers[branchId] = govManager;
        branchProvisioned[branchId] = true;

        emit BranchProvisioned(branchId, orgId, staffManager);
    }

    /**
     * @dev Enable module cho branch.
     */
    function enableModule(uint48 branchId, bytes32 moduleKey) external onlyPlatformAdmin returns (address moduleRoot) {
        if (!branchProvisioned[branchId]) {
            revert BranchNotProvisioned();
        }

        if (branchEnabledModules[branchId].contains(moduleKey)) {
            revert ModuleAlreadyEnabled();
        }

        uint48 orgId = organizationManager.getBranchOrgId(branchId);

        if (!moduleRegistry.isOrgSubscribed(orgId, moduleKey)) {
            revert OrgNotSubscribedToModule();
        }

        if (!moduleRegistry.isModuleActive(moduleKey)) {
            revert OrgNotSubscribedToModule();
        }

        address factoryAddress = moduleRegistry.getModuleFactory(moduleKey);

        moduleRoot = IModuleFactory(factoryAddress).deployModule(branchId, orgId, branchStaffManagers[branchId]);

        branchModuleRoots[branchId][moduleKey] = moduleRoot;
        branchEnabledModules[branchId].add(moduleKey);

        emit ModuleEnabled(branchId, moduleKey, moduleRoot);
    }

    /**
     * @dev Disable module.
     */
    function disableModule(uint48 branchId, bytes32 moduleKey) external onlyPlatformAdmin {
        if (!branchEnabledModules[branchId].contains(moduleKey)) {
            revert ModuleNotEnabled();
        }

        branchEnabledModules[branchId].remove(moduleKey);
        emit ModuleDisabled(branchId, moduleKey);
    }

    // ====== View Functions ======

    function isBranchProvisioned(uint48 branchId) external view returns (bool) {
        return branchProvisioned[branchId];
    }

    function getBranchStaffManager(uint48 branchId) external view returns (address) {
        return branchStaffManagers[branchId];
    }

    function getModuleRoot(uint48 branchId, bytes32 moduleKey) external view returns (address) {
        return branchModuleRoots[branchId][moduleKey];
    }

    function getBranchModules(uint48 branchId) external view returns (bytes32[] memory keys, address[] memory roots) {
        EnumerableSet.Bytes32Set storage modules = branchEnabledModules[branchId];
        uint256 length = modules.length();

        keys = new bytes32[](length);
        roots = new address[](length);

        for (uint256 i; i < length; i++) {
            bytes32 key = modules.at(i);
            keys[i] = key;
            roots[i] = branchModuleRoots[branchId][key];
        }
    }

    function isModuleEnabled(uint48 branchId, bytes32 moduleKey) external view returns (bool) {
        return branchEnabledModules[branchId].contains(moduleKey);
    }

    // ====== Internal ======

    function _authorizeUpgrade(address newImplementation) internal override {
        if (!accessControl.hasRole(RoleHashes.DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert Unauthorized();
        }
    }
}
