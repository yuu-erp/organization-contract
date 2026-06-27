// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title BranchStaffManagerStorage
 * @dev Định nghĩa bố cục bộ nhớ (Storage Layout) của BranchStaffManager, loại bỏ logic voting cũ và giữ nguyên tương thích slot.
 */
abstract contract BranchStaffManagerStorage {
    using EnumerableSet for EnumerableSet.AddressSet;

    // Định nghĩa Role nội bộ bằng uint8
    uint8 public constant ROLE_CO_OWNER = 1;
    uint8 public constant ROLE_MANAGER = 2;
    uint8 public constant ROLE_STAFF = 3;

    // --- 1. GLOBAL PERMISSIONS (Quyền dùng chung cho mọi module) ---
    uint248 public constant GLOBAL_PERM_CASHIER = 1 << 0;
    uint248 public constant GLOBAL_PERM_REPORTS = 1 << 1;

    // Tối ưu Storage: Gom Role và Global Perms vào 1 Slot
    struct StaffProfile {
        uint8 role; // 8 bits
        uint248 globalPerms; // 248 bits
    }

    // --- Tối ưu Storage Packing (Slot 1: 160 + 48 + 48 = 256 bits) ---
    address public organizationManager; // 160 bits
    uint48 public branchId; // 48 bits
    uint48 public orgId; // 48 bits

    // Lưu trữ hồ sơ nhân sự (Role + Global Permissions)
    mapping(address => StaffProfile) internal _staffProfiles;

    // --- 2. MODULE PERMISSIONS (Quyền riêng theo từng Module) ---
    mapping(address => mapping(bytes32 => uint256)) internal _modulePerms;

    // ====== DUMMY VARIABLES ĐỂ GIỮ NGUYÊN SLOT COMPATIBILITY ======
    uint256 private __deprecatedVotingDuration;
    uint256 private __deprecatedProposalCounter;
    mapping(uint256 => bytes32) private __deprecatedProposals; // Đổi kiểu từ struct sang bytes32 mapping để tránh import struct
    mapping(uint256 => mapping(address => bool)) private __deprecatedProposalVoted;

    // EnumerableSet để lưu trữ danh sách co-owners của chi nhánh
    EnumerableSet.AddressSet internal _coOwners;

    // Địa chỉ StaffMetadataRegistry
    address public staffMetadataRegistry;

    // Biến tạm cũ đã deprecate
    bool private __deprecatedExecutingProposal;

    // ====== CÁC BIẾN MỚI CHO THIẾT KẾ PHÂN TÁCH ======
    address public branchGovernanceManager;

    /**
     * @dev Khoảng trống dự phòng để cho phép thêm các biến storage trong tương lai mà không bị xung đột bộ nhớ.
     */
    uint256[46] private __gap; // Giảm xuống 46 slot vì đã thêm 1 slot cho branchGovernanceManager
}
