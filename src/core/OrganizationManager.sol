// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {RoleHashes} from "./constants/RoleHashes.sol";

import {ISystemAccessControl} from "./interfaces/ISystemAccessControl.sol";
import {IOrganizationManager} from "./interfaces/IOrganizationManager.sol";
import {IModuleRegistry} from "./interfaces/IModuleRegistry.sol";
import {IBranchModuleManager} from "./interfaces/IBranchModuleManager.sol";

import {OrganizationTypes} from "../types/OrganizationTypes.sol";
import {BranchTypes} from "../types/BranchTypes.sol";

import {OrganizationManagerStorage} from "./storage/OrganizationManagerStorage.sol";

/**
 * @title OrganizationManager
 * @dev Quản lý vòng đời Organization và Branch của nền tảng (Đã tối ưu Storage Packing).
 */
contract OrganizationManager is Initializable, UUPSUpgradeable, OrganizationManagerStorage, IOrganizationManager {
    using EnumerableSet for EnumerableSet.UintSet;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Khởi tạo contract.
     * @param accessControlAddress Địa chỉ SystemAccessControl.
     */
    function initialize(address accessControlAddress) external initializer {
        if (accessControlAddress == address(0)) {
            revert InvalidAddress();
        }

        accessControl = ISystemAccessControl(accessControlAddress);
    }

    /**
     * @dev Chỉ Platform Admin mới được phép thực hiện.
     */
    modifier onlyPlatformAdmin() {
        if (!accessControl.hasRole(RoleHashes.PLATFORM_ADMIN_ROLE, msg.sender)) {
            revert Unauthorized();
        }
        _;
    }

    /**
     * @dev Tạo mới Organization kèm đăng ký module.
     */
    function createOrganization(address owner, bytes32[] calldata moduleKeys)
        external
        onlyPlatformAdmin
        returns (uint48 organizationId)
    {
        if (owner == address(0)) {
            revert InvalidAddress();
        }

        if (ownerToOrganizationId[owner] != 0) {
            revert OrganizationAlreadyExists();
        }

        organizationId = ++organizationCounter;

        organizations[organizationId] =
            OrganizationTypes.Organization({owner: owner, id: organizationId, active: true, exists: true});

        ownerToOrganizationId[owner] = organizationId;

        emit OrganizationCreated(organizationId, owner);

        // Tự động subscribe các module
        if (moduleRegistry != address(0)) {
            for (uint256 i = 0; i < moduleKeys.length; i++) {
                IModuleRegistry(moduleRegistry).subscribeOrgToModule(organizationId, moduleKeys[i]);
            }
        }
    }

    /**
     * @dev Tạo mới Branch cho Organization kèm kích hoạt module.
     */
    function createBranch(uint48 organizationId, bytes32[] calldata moduleKeysToEnable)
        external
        onlyPlatformAdmin
        returns (uint48 branchId)
    {
        _requireOrganizationExists(organizationId);

        branchId = ++branchCounter;

        branches[branchId] =
            BranchTypes.Branch({owner: address(0), organizationId: organizationId, active: true, exists: true});

        organizationBranches[organizationId].add(branchId);

        emit BranchCreated(branchId, organizationId);

        // Tự động provision và kích hoạt các module
        if (branchModuleManager != address(0)) {
            IBranchModuleManager(branchModuleManager).provisionBranch(branchId, organizationId);

            for (uint256 i = 0; i < moduleKeysToEnable.length; i++) {
                IBranchModuleManager(branchModuleManager).enableModule(branchId, moduleKeysToEnable[i]);
            }
        }
    }

    /**
     * @dev Cập nhật địa chỉ ModuleRegistry và BranchModuleManager.
     */
    function setRegistryAndManager(address _moduleRegistry, address _branchModuleManager) external onlyPlatformAdmin {
        if (_moduleRegistry == address(0) || _branchModuleManager == address(0)) {
            revert InvalidAddress();
        }
        moduleRegistry = _moduleRegistry;
        branchModuleManager = _branchModuleManager;
    }

    /**
     * @dev Trả về organizationId của owner.
     */
    function getOrganizationIdByOwner(address owner) external view returns (uint48) {
        return ownerToOrganizationId[owner];
    }

    /**
     * @dev Trả về danh sách Branch thuộc Organization.
     */
    function getOrganizationBranches(uint48 organizationId) external view returns (uint48[] memory branchIds) {
        _requireOrganizationExists(organizationId);

        EnumerableSet.UintSet storage branchesSet = organizationBranches[organizationId];

        uint256 length = branchesSet.length();
        branchIds = new uint48[](length);

        for (uint256 i; i < length; i++) {
            // Ép kiểu an toàn từ uint256 xuống uint48
            branchIds[i] = uint48(branchesSet.at(i));
        }
    }

    /**
     * @dev Kiểm tra Organization tồn tại.
     */
    function organizationExists(uint48 organizationId) external view returns (bool) {
        return organizations[organizationId].exists;
    }

    /**
     * @dev Trả về organizationId của branch.
     */
    function getBranchOrgId(uint48 branchId) external view returns (uint48) {
        return branches[branchId].organizationId;
    }

    /**
     * @dev Kiểm tra Branch tồn tại.
     */
    function branchExists(uint48 branchId) external view returns (bool) {
        return branches[branchId].exists;
    }

    /**
     * @dev Validate Organization tồn tại.
     */
    function _requireOrganizationExists(uint48 organizationId) internal view {
        if (!organizations[organizationId].exists) {
            revert OrganizationNotFound();
        }
    }

    /**
     * @dev Validate Branch tồn tại.
     */
    function _requireBranchExists(uint48 branchId) internal view {
        if (!branches[branchId].exists) {
            revert BranchNotFound();
        }
    }

    /**
     * @dev Chỉ Owner hệ thống mới được phép nâng cấp.
     */
    function _authorizeUpgrade(address newImplementation) internal override {
        if (!accessControl.hasRole(RoleHashes.DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert Unauthorized();
        }
    }
}
