// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

enum ProposalType { AddOrUpdateProfile, RevokeRole, SetModulePermissions, UpdateMetadata }
enum ProposalState { Active, Executed, Canceled }

/**
 * @title BranchStaffManagerStorage
 * @dev Định nghĩa bố cục bộ nhớ (Storage Layout) của BranchStaffManager.
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

    // Lưu trữ hồ sơ nhân sự (Role + Global Permissions) - đổi tên thành _staffProfiles để tránh trùng getter
    mapping(address => StaffProfile) internal _staffProfiles;

    // --- 2. MODULE PERMISSIONS (Quyền riêng theo từng Module) ---
    mapping(address => mapping(bytes32 => uint256)) public modulePerms;

    // ====== TRẠNG THÁI VÀ ĐỊNH NGHĨA QUẢN TRỊ (VOTING) ======
    uint256 public constant VOTING_DURATION = 7 days;

    struct Proposal {
        uint256 id;
        ProposalType proposalType;
        address target;
        uint8 role;
        uint248 globalPerms;
        bytes32 moduleKey;
        uint256 modulePerms;
        string metadataName;
        string metadataPhone;
        string metadataAvatar;
        uint256 endTime;
        uint256 yesVotes;
        uint256 noVotes;
        uint256 totalVotersAtCreation;
        ProposalState state;
        address creator;
    }

    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public proposalVoted;
    uint256 public proposalCounter;

    // EnumerableSet để lưu trữ danh sách co-owners của chi nhánh
    EnumerableSet.AddressSet internal _coOwners;

    // Địa chỉ StaffMetadataRegistry
    address public staffMetadataRegistry;

    // Flag tạm thời để bypass kiểm tra Guard Clause khi thực thi Proposal
    bool internal _executingProposal;

    /**
     * @dev Khoảng trống dự phòng để cho phép thêm các biến storage trong tương lai mà không bị xung đột bộ nhớ.
     */
    uint256[47] private __gap;
}
