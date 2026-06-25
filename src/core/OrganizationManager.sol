// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {RoleHashes} from "./constants/RoleHashes.sol";

import {ISystemAccessControl} from "./interfaces/ISystemAccessControl.sol";
import {IOrganizationManager} from "./interfaces/IOrganizationManager.sol";

import {OrganizationTypes} from "../types/OrganizationTypes.sol";
import {BranchTypes} from "../types/BranchTypes.sol";

import {OrganizationManagerStorage} from "./storage/OrganizationManagerStorage.sol";

/**
 * @title OrganizationManager
 * @dev Quản lý vòng đời Organization và Branch của nền tảng.
 */
contract OrganizationManager is
    Initializable,
    UUPSUpgradeable,
    OrganizationManagerStorage,
    IOrganizationManager
{
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
        if (
            !accessControl.hasRole(RoleHashes.PLATFORM_ADMIN_ROLE, msg.sender)
        ) {
            revert Unauthorized();
        }

        _;
    }

    /**
     * @dev Tạo mới Organization.
     */
    function createOrganization(
        address owner
    ) external onlyPlatformAdmin returns (uint256 organizationId) {
        if (owner == address(0)) {
            revert InvalidAddress();
        }

        if (ownerToOrganizationId[owner] != 0) {
            revert OrganizationAlreadyExists();
        }

        organizationId = ++organizationCounter;

        organizations[organizationId] = OrganizationTypes.Organization({
            id: organizationId,
            owner: owner,
            active: true,
            exists: true
        });

        ownerToOrganizationId[owner] = organizationId;

        emit OrganizationCreated(organizationId, owner);
    }

    /**
     * @dev Tạo mới Branch cho Organization.
     */
    function createBranch(
        uint256 organizationId
    ) external onlyPlatformAdmin returns (uint256 branchId) {
        _requireOrganizationExists(organizationId);

        branchId = ++branchCounter;

        branches[branchId] = BranchTypes.Branch({
            organizationId: organizationId,
            owner: address(0),
            active: true,
            exists: true
        });

        organizationBranches[organizationId].add(branchId);

        emit BranchCreated(branchId, organizationId);
    }

    /**
     * @dev Trả về organizationId của owner.
     */
    function getOrganizationIdByOwner(
        address owner
    ) external view returns (uint256) {
        return ownerToOrganizationId[owner];
    }

    /**
     * @dev Trả về danh sách Branch thuộc Organization.
     */
    function getOrganizationBranches(
        uint256 organizationId
    ) external view returns (uint256[] memory branchIds) {
        _requireOrganizationExists(organizationId);

        EnumerableSet.UintSet storage branchesSet = organizationBranches[
            organizationId
        ];

        uint256 length = branchesSet.length();

        branchIds = new uint256[](length);

        for (uint256 i; i < length; i++) {
            branchIds[i] = branchesSet.at(i);
        }
    }

    /**
     * @dev Kiểm tra Organization tồn tại.
     */
    function organizationExists(
        uint256 organizationId
    ) external view returns (bool) {
        return organizations[organizationId].exists;
    }

    /**
     * @dev Kiểm tra Branch tồn tại.
     */
    function branchExists(uint256 branchId) external view returns (bool) {
        return branches[branchId].exists;
    }

    /**
     * @dev Validate Organization tồn tại.
     */
    function _requireOrganizationExists(uint256 organizationId) internal view {
        if (!organizations[organizationId].exists) {
            revert OrganizationNotFound();
        }
    }

    /**
     * @dev Validate Branch tồn tại.
     */
    function _requireBranchExists(uint256 branchId) internal view {
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
