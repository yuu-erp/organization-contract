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
    function coOwnerCount() external view returns (uint256);
    function branchGovernanceManager() external view returns (address);
}

/**
 * @title StaffMetadataRegistry
 * @dev Hợp đồng quản lý metadata (name, phoneNumber, avatar) tập trung cho nhân sự.
 */
contract StaffMetadataRegistry is Initializable, UUPSUpgradeable, StaffMetadataRegistryStorage, IStaffMetadataRegistry {
    
    error RequiresProposal();
    error InvalidAddress();
    error BranchNotProvisioned();
    error Unauthorized();

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
     * 0. Hợp đồng BranchGovernanceManager hợp lệ của chi nhánh đó (nếu được gọi từ proposal execution).
     * 1. Chính bản thân nhân viên đó (`msg.sender == staff`).
     * 2. Platform Admin hoặc Default Admin của hệ thống.
     * 3. Owner của Tổ chức sở hữu chi nhánh đó.
     * 4. Co-owner hoặc Manager của chi nhánh đó (được check qua BranchStaffManager).
     */
    modifier onlyStaffOrAuthorizedManager(uint48 branchId, address staff) {
        // Guardrail 4: Bảo mật xác thực chéo (Cross-Contract Authentication)
        // Lấy StaffManager chính thức từ BranchModuleManager (hợp đồng tin cậy)
        address staffManager = branchModuleManager.getBranchStaffManager(branchId);
        
        if (staffManager != address(0)) {
            // Lấy địa chỉ Governance từ StaffManager để tránh giả mạo
            address govManager = IBranchStaffManagerGetter(staffManager).branchGovernanceManager();
            if (msg.sender == govManager && govManager != address(0)) {
                // Cho phép trực tiếp nếu cuộc gọi đến từ BranchGovernanceManager thực thi Proposal
                _;
                return;
            }
        }

        // Kiểm tra nếu target là Co-owner hoặc Manager, và chi nhánh có co-owner,
        // thì bắt buộc phải đi qua voting proposal của BranchGovernanceManager (không được gọi trực tiếp).
        if (staffManager != address(0)) {
            (uint8 role,) = IBranchStaffManagerGetter(staffManager).staffProfiles(staff);
            uint256 coOwnersCount = IBranchStaffManagerGetter(staffManager).coOwnerCount();
            
            // ROLE_CO_OWNER = 1, ROLE_MANAGER = 2
            if ((role == 1 || role == 2) && coOwnersCount > 0) {
                revert RequiresProposal();
            }
        }

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
