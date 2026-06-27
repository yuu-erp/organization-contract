// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {RoleHashes} from "../core/constants/RoleHashes.sol";
import {ISystemAccessControl} from "../core/interfaces/ISystemAccessControl.sol";
import {IOrganizationManager} from "../core/interfaces/IOrganizationManager.sol";
import {IBranchModuleManager} from "../core/interfaces/IBranchModuleManager.sol";
import {IStaffMetadataRegistry} from "./interfaces/IStaffMetadataRegistry.sol";
import {StaffMetadataRegistryStorage} from "./storage/StaffMetadataRegistryStorage.sol";
import {StaffTypes} from "../types/StaffTypes.sol";

interface IBranchStaffManagerGetter {
    function staffProfiles(address staff) external view returns (uint8 role, uint248 globalPerms);
}

/**
 * @title StaffMetadataRegistry
 * @dev Hợp đồng quản lý metadata (name, phoneNumber, avatar) tập trung cho nhân sự.
 */
contract StaffMetadataRegistry is Initializable, UUPSUpgradeable, StaffMetadataRegistryStorage, IStaffMetadataRegistry {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Hàm khởi tạo chạy 1 lần duy nhất cho Proxy.
     */
    function initialize(
        address accessControlAddress,
        address organizationManagerAddress,
        address branchModuleManagerAddress
    ) external initializer {
        if (
            accessControlAddress == address(0) || organizationManagerAddress == address(0)
                || branchModuleManagerAddress == address(0)
        ) {
            revert InvalidAddress();
        }

        accessControl = ISystemAccessControl(accessControlAddress);
        organizationManager = IOrganizationManager(organizationManagerAddress);
        branchModuleManager = IBranchModuleManager(branchModuleManagerAddress);
    }

    /**
     * @dev Modifier kiểm tra quyền chỉnh sửa metadata của nhân viên.
     * Người gọi hợp lệ bao gồm:
     * 1. Chính bản thân nhân viên đó (`msg.sender == staff`).
     * 2. Platform Admin hoặc Default Admin của hệ thống.
     * 3. Owner của Tổ chức sở hữu chi nhánh đó.
     * 4. Co-owner hoặc Manager của chi nhánh đó (được check qua BranchStaffManager).
     */
    modifier onlyStaffOrAuthorizedManager(uint48 branchId, address staff) {
        if (msg.sender != staff) {
            // 1. Kiểm tra Platform Admin / Default Admin
            bool isSystemAdmin = accessControl.hasRole(RoleHashes.DEFAULT_ADMIN_ROLE, msg.sender)
                || accessControl.hasRole(RoleHashes.PLATFORM_ADMIN_ROLE, msg.sender);

            if (!isSystemAdmin) {
                // 2. Kiểm tra Owner của Tổ chức sở hữu chi nhánh
                uint48 orgId = organizationManager.getBranchOrgId(branchId);
                bool isOrgOwner = organizationManager.getOrganizationIdByOwner(msg.sender) == orgId;

                if (!isOrgOwner) {
                    // 3. Kiểm tra Co-owner hoặc Manager của chi nhánh
                    address staffManager = branchModuleManager.getBranchStaffManager(branchId);
                    if (staffManager == address(0)) {
                        revert BranchNotProvisioned();
                    }

                    (uint8 role,) = IBranchStaffManagerGetter(staffManager).staffProfiles(msg.sender);
                    // ROLE_CO_OWNER = 1, ROLE_MANAGER = 2
                    bool isBranchAdmin = (role == 1 || role == 2);

                    if (!isBranchAdmin) {
                        revert Unauthorized();
                    }
                }
            }
        }
        _;
    }

    /**
     * @dev Cập nhật metadata cho nhân viên tại chi nhánh cụ thể.
     */
    function setStaffMetadata(
        uint48 branchId,
        address staff,
        string calldata name,
        string calldata phoneNumber,
        string calldata avatar
    ) external override onlyStaffOrAuthorizedManager(branchId, staff) {
        if (staff == address(0)) {
            revert InvalidAddress();
        }

        _staffMetadata[branchId][staff] =
            StaffTypes.StaffMetadata({name: name, phoneNumber: phoneNumber, avatar: avatar});

        emit StaffMetadataUpdated(branchId, staff, name, phoneNumber, avatar);
    }

    /**
     * @dev Đọc metadata của nhân viên tại chi nhánh.
     */
    function getStaffMetadata(uint48 branchId, address staff)
        external
        view
        override
        returns (StaffTypes.StaffMetadata memory)
    {
        return _staffMetadata[branchId][staff];
    }

    /**
     * @dev Chỉ DEFAULT_ADMIN mới được nâng cấp.
     */
    function _authorizeUpgrade(address newImplementation) internal override {
        if (!accessControl.hasRole(RoleHashes.DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert Unauthorized();
        }
    }
}
