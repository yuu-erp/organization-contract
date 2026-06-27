// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {RoleHashes} from "../core/constants/RoleHashes.sol";
import {ISystemAccessControl} from "../core/interfaces/ISystemAccessControl.sol";
import {IOrganizationManager} from "../core/interfaces/IOrganizationManager.sol";
import {IOrganizationMetadataRegistry} from "./interfaces/IOrganizationMetadataRegistry.sol";
import {OrganizationMetadataRegistryStorage} from "./storage/OrganizationMetadataRegistryStorage.sol";
import {OrganizationTypes} from "../types/OrganizationTypes.sol";
import {BranchTypes} from "../types/BranchTypes.sol";

/**
 * @title OrganizationMetadataRegistry
 * @dev Registry độc lập lưu trữ metadata cho Organization & Branch (100% on-chain, tách biệt khỏi core logic).
 */
contract OrganizationMetadataRegistry is
    Initializable,
    UUPSUpgradeable,
    OrganizationMetadataRegistryStorage,
    IOrganizationMetadataRegistry
{
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Khởi tạo registry.
     * @param accessControlAddress Địa chỉ SystemAccessControl.
     * @param organizationManagerAddress Địa chỉ OrganizationManager.
     */
    function initialize(address accessControlAddress, address organizationManagerAddress) external initializer {
        if (accessControlAddress == address(0) || organizationManagerAddress == address(0)) {
            revert InvalidAddress();
        }

        accessControl = ISystemAccessControl(accessControlAddress);
        organizationManager = IOrganizationManager(organizationManagerAddress);
    }

    /**
     * @dev Modifier check xem người gọi có quyền sửa đổi metadata của Organization hay không.
     * Người gọi phải là Owner của Organization hoặc là Platform Admin / Default Admin.
     */
    modifier onlyOrganizationOwnerOrAdmin(uint48 organizationId) {
        if (!organizationManager.organizationExists(organizationId)) {
            revert OrganizationNotFound();
        }

        bool isOwner = organizationManager.getOrganizationIdByOwner(msg.sender) == organizationId;
        bool isAdmin = accessControl.hasRole(RoleHashes.PLATFORM_ADMIN_ROLE, msg.sender) ||
            accessControl.hasRole(RoleHashes.DEFAULT_ADMIN_ROLE, msg.sender);

        if (!isOwner && !isAdmin) {
            revert Unauthorized();
        }
        _;
    }

    /**
     * @dev Modifier check xem người gọi có quyền sửa đổi metadata của Branch hay không.
     */
    modifier onlyBranchOwnerOrAdmin(uint48 branchId) {
        if (!organizationManager.branchExists(branchId)) {
            revert BranchNotFound();
        }

        uint48 organizationId = organizationManager.getBranchOrgId(branchId);
        bool isOwner = organizationManager.getOrganizationIdByOwner(msg.sender) == organizationId;
        bool isAdmin = accessControl.hasRole(RoleHashes.PLATFORM_ADMIN_ROLE, msg.sender) ||
            accessControl.hasRole(RoleHashes.DEFAULT_ADMIN_ROLE, msg.sender);

        if (!isOwner && !isAdmin) {
            revert Unauthorized();
        }
        _;
    }

    /**
     * @dev Cập nhật metadata cho Organization.
     */
    function setOrganizationMetadata(
        uint48 organizationId,
        string calldata name,
        string calldata organizationAddress,
        string calldata phoneNumber
    ) external override onlyOrganizationOwnerOrAdmin(organizationId) {
        _orgMetadata[organizationId] = OrganizationTypes.OrganizationMetadata({
            name: name,
            organizationAddress: organizationAddress,
            phoneNumber: phoneNumber
        });

        emit OrganizationMetadataUpdated(organizationId, name, organizationAddress, phoneNumber);
    }

    /**
     * @dev Cập nhật metadata cho Branch.
     */
    function setBranchMetadata(
        uint48 branchId,
        string calldata name,
        string calldata organizationAddress,
        string calldata phoneNumber,
        string calldata code
    ) external override onlyBranchOwnerOrAdmin(branchId) {
        _branchMetadata[branchId] = BranchTypes.BranchMetadata({
            name: name,
            organizationAddress: organizationAddress,
            phoneNumber: phoneNumber,
            code: code
        });

        emit BranchMetadataUpdated(branchId, name, organizationAddress, phoneNumber, code);
    }

    /**
     * @dev Trả về metadata của Organization.
     */
    function getOrganizationMetadata(uint48 organizationId)
        external
        view
        override
        returns (OrganizationTypes.OrganizationMetadata memory)
    {
        if (!organizationManager.organizationExists(organizationId)) {
            revert OrganizationNotFound();
        }
        return _orgMetadata[organizationId];
    }

    /**
     * @dev Trả về metadata của Branch.
     */
    function getBranchMetadata(uint48 branchId)
        external
        view
        override
        returns (BranchTypes.BranchMetadata memory)
    {
        if (!organizationManager.branchExists(branchId)) {
            revert BranchNotFound();
        }
        return _branchMetadata[branchId];
    }

    /**
     * @dev Chỉ Owner hệ thống mới được phép nâng cấp proxy.
     */
    function _authorizeUpgrade(address newImplementation) internal override {
        if (!accessControl.hasRole(RoleHashes.DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert Unauthorized();
        }
    }
}
