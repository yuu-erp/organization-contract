// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {GovernanceTypes} from "../../types/GovernanceTypes.sol";

/**
 * @title IBranchGovernanceManager
 * @dev Giao diện quản lý biểu quyết và thực thi đề xuất tại chi nhánh.
 */
interface IBranchGovernanceManager {
    
    // ====== EVENTS ======
    
    /**
     * @dev Phát ra khi đề xuất được tạo.
     * Lưu ý: Emit các tham số string tại đây để Frontend index và lưu trữ.
     */
    event ProposalCreated(
        uint256 indexed proposalId,
        GovernanceTypes.ProposalType indexed proposalType,
        address indexed target,
        string name,
        string phone,
        string avatar
    );

    /**
     * @dev Phát ra khi một cử tri bỏ phiếu.
     */
    event Voted(uint256 indexed proposalId, address indexed voter, bool support);

    /**
     * @dev Phát ra khi đề xuất được thực thi thành công.
     */
    event ProposalExecuted(uint256 indexed proposalId);

    /**
     * @dev Phát ra khi đề xuất bị hủy bỏ.
     */
    event ProposalCanceled(uint256 indexed proposalId);

    // ====== CUSTOM ERRORS ======
    error Unauthorized();
    error ProposalNotActive();
    error ProposalExpired();
    error ProposalAlreadyVoted();
    error ProposalCannotBeExecuted();
    error HashMismatch();

    // ====== CORE FUNCTIONS ======

    /**
     * @dev Tạo đề xuất mới thay đổi cấu hình nhân sự hoặc metadata.
     * @param proposalType Loại đề xuất.
     * @param target Địa chỉ đích chịu tác động.
     * @param role Vai trò cần gán.
     * @param globalPerms Quyền hạn toàn cục cần gán.
     * @param moduleKey Định danh module cần gán quyền riêng biệt.
     * @param modulePermBitmask Bitmask quyền hạn của module.
     * @param name Tên nhân sự (dùng để hash).
     * @param phone Số điện thoại (dùng để hash).
     * @param avatar Ảnh đại diện (dùng để hash).
     * @return proposalId ID của đề xuất được tạo.
     */
    function createProposal(
        GovernanceTypes.ProposalType proposalType,
        address target,
        uint8 role,
        uint248 globalPerms,
        bytes32 moduleKey,
        uint256 modulePermBitmask,
        string calldata name,
        string calldata phone,
        string calldata avatar
    ) external returns (uint256 proposalId);

    /**
     * @dev Bỏ phiếu thuận hoặc chống cho một đề xuất đang hoạt động.
     * @param proposalId ID của đề xuất.
     * @param support true nếu ủng hộ (Yes), false nếu phản đối (No).
     */
    function voteProposal(uint256 proposalId, bool support) external;

    /**
     * @dev Thực thi đề xuất khi đạt đủ số lượng phiếu thuận.
     * @param proposalId ID của đề xuất.
     * @param name Tên nhân sự (để verify hash).
     * @param phone Số điện thoại (để verify hash).
     * @param avatar Ảnh đại diện (để verify hash).
     */
    function executeProposal(
        uint256 proposalId,
        string calldata name,
        string calldata phone,
        string calldata avatar
    ) external;

    /**
     * @dev Hủy bỏ một đề xuất đang hoạt động.
     * Chỉ người tạo đề xuất hoặc Organization Owner mới được phép hủy.
     * @param proposalId ID của đề xuất cần hủy.
     */
    function cancelProposal(uint256 proposalId) external;
}
