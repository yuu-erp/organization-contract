// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {RoleHashes} from "./constants/RoleHashes.sol";

import {ISystemAccessControl} from "./interfaces/ISystemAccessControl.sol";
import {IOrganizationManager} from "./interfaces/IOrganizationManager.sol";
import {IModuleRegistry} from "./interfaces/IModuleRegistry.sol";
import {IBranchModuleManager} from "./interfaces/IBranchModuleManager.sol";
import {IModuleFactory} from "./interfaces/IModuleFactory.sol";

import {BranchModuleManagerStorage} from "./storage/BranchModuleManagerStorage.sol";

/**
 * @title BranchModuleManager
 * @dev Orchestrator chính: provision branch, deploy shared services và module bundles.
 *
 *      Flow:
 *      1. provisionBranch(branchId, orgId) → deploy BranchStaffManager
 *      2. enableModule(branchId, moduleKey) → gọi factory deploy module bundle
 *      3. disableModule(branchId, moduleKey) → soft disable
 */
contract BranchModuleManager is
    Initializable,
    UUPSUpgradeable,
    BranchModuleManagerStorage,
    IBranchModuleManager
{
    using EnumerableSet for EnumerableSet.Bytes32Set;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Khởi tạo contract.
     * @param accessControlAddress Địa chỉ SystemAccessControl
     * @param organizationManagerAddress Địa chỉ OrganizationManager proxy
     * @param moduleRegistryAddress Địa chỉ ModuleRegistry proxy
     * @param staffManagerBeaconAddress Địa chỉ Beacon cho BranchStaffManager
     */
    function initialize(
        address accessControlAddress,
        address organizationManagerAddress,
        address moduleRegistryAddress,
        address staffManagerBeaconAddress
    ) external initializer {
        if (
            accessControlAddress == address(0) ||
            organizationManagerAddress == address(0) ||
            moduleRegistryAddress == address(0) ||
            staffManagerBeaconAddress == address(0)
        ) {
            revert InvalidAddress();
        }

        accessControl = ISystemAccessControl(accessControlAddress);
        organizationManager = IOrganizationManager(
            organizationManagerAddress
        );
        moduleRegistry = IModuleRegistry(moduleRegistryAddress);
        staffManagerBeacon = staffManagerBeaconAddress;
    }

    // ====== Modifiers ======

    modifier onlyPlatformAdmin() {
        if (
            !accessControl.hasRole(RoleHashes.PLATFORM_ADMIN_ROLE, msg.sender)
        ) {
            revert Unauthorized();
        }
        _;
    }

    // ====== Core Functions ======

    /**
     * @dev Provision branch: deploy BranchStaffManager (shared service).
     *      Phải gọi trước khi enableModule.
     */
    function provisionBranch(
        uint256 branchId,
        uint256 orgId
    ) external onlyPlatformAdmin {
        // Validate branch exists
        if (!organizationManager.branchExists(branchId)) {
            revert InvalidInput();
        }

        if (branchProvisioned[branchId]) {
            revert BranchAlreadyProvisioned();
        }

        // Deploy BranchStaffManager via Beacon Proxy
        address staffManager = address(
            new BeaconProxy(
                staffManagerBeacon,
                abi.encodeWithSignature(
                    "initialize(uint256,address)",
                    branchId,
                    address(accessControl)
                )
            )
        );

        branchStaffManagers[branchId] = staffManager;
        branchProvisioned[branchId] = true;

        emit BranchProvisioned(branchId, orgId, staffManager);
    }

    /**
     * @dev Enable module cho branch.
     *      Gọi factory tương ứng để deploy toàn bộ module bundle.
     */
    function enableModule(
        uint256 branchId,
        bytes32 moduleKey
    ) external onlyPlatformAdmin returns (address moduleRoot) {
        if (!branchProvisioned[branchId]) {
            revert BranchNotProvisioned();
        }

        if (branchEnabledModules[branchId].contains(moduleKey)) {
            revert ModuleAlreadyEnabled();
        }

        // Lấy orgId từ branch
        uint256 orgId = organizationManager.getBranchOrgId(branchId);

        // Check org đã subscribe module này chưa
        if (!moduleRegistry.isOrgSubscribed(orgId, moduleKey)) {
            revert OrgNotSubscribedToModule();
        }

        // Check module active
        if (!moduleRegistry.isModuleActive(moduleKey)) {
            revert OrgNotSubscribedToModule();
        }

        // Lấy factory address
        address factoryAddress = moduleRegistry.getModuleFactory(moduleKey);

        // Gọi factory deploy module bundle
        moduleRoot = IModuleFactory(factoryAddress).deployModule(
            branchId,
            orgId,
            branchStaffManagers[branchId]
        );

        // Lưu state
        branchModuleRoots[branchId][moduleKey] = moduleRoot;
        branchEnabledModules[branchId].add(moduleKey);

        emit ModuleEnabled(branchId, moduleKey, moduleRoot);
    }

    /**
     * @dev Disable module (soft — giữ data, chỉ remove khỏi enabled set).
     */
    function disableModule(
        uint256 branchId,
        bytes32 moduleKey
    ) external onlyPlatformAdmin {
        if (!branchEnabledModules[branchId].contains(moduleKey)) {
            revert ModuleNotEnabled();
        }

        branchEnabledModules[branchId].remove(moduleKey);

        // Không xóa branchModuleRoots → giữ reference để query data cũ

        emit ModuleDisabled(branchId, moduleKey);
    }

    // ====== View Functions ======

    /**
     * @dev Kiểm tra branch đã provision chưa.
     */
    function isBranchProvisioned(
        uint256 branchId
    ) external view returns (bool) {
        return branchProvisioned[branchId];
    }

    /**
     * @dev Lấy StaffManager address.
     */
    function getBranchStaffManager(
        uint256 branchId
    ) external view returns (address) {
        return branchStaffManagers[branchId];
    }

    /**
     * @dev Lấy module root address.
     */
    function getModuleRoot(
        uint256 branchId,
        bytes32 moduleKey
    ) external view returns (address) {
        return branchModuleRoots[branchId][moduleKey];
    }

    /**
     * @dev Lấy danh sách module keys + addresses đang enabled của branch.
     */
    function getBranchModules(
        uint256 branchId
    )
        external
        view
        returns (bytes32[] memory keys, address[] memory roots)
    {
        EnumerableSet.Bytes32Set storage modules = branchEnabledModules[
            branchId
        ];
        uint256 length = modules.length();

        keys = new bytes32[](length);
        roots = new address[](length);

        for (uint256 i; i < length; i++) {
            bytes32 key = modules.at(i);
            keys[i] = key;
            roots[i] = branchModuleRoots[branchId][key];
        }
    }

    /**
     * @dev Kiểm tra module đang enabled cho branch không.
     */
    function isModuleEnabled(
        uint256 branchId,
        bytes32 moduleKey
    ) external view returns (bool) {
        return branchEnabledModules[branchId].contains(moduleKey);
    }

    // ====== Internal ======

    /**
     * @dev Chỉ DEFAULT_ADMIN mới được nâng cấp.
     */
    function _authorizeUpgrade(
        address newImplementation
    ) internal override {
        if (!accessControl.hasRole(RoleHashes.DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert Unauthorized();
        }
    }
}
