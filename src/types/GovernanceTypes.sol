// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title GovernanceTypes
 * @dev Định nghĩa các kiểu dữ liệu dùng chung cho hệ thống quản trị và bỏ phiếu.
 */
library GovernanceTypes {
    /**
     * @dev Các loại đề xuất hành động quản trị chi nhánh.
     */
    enum ProposalType {
        AddOrUpdateProfile,
        RevokeRole,
        UpdateMetadata
    }

    /**
     * @dev Các trạng thái vòng đời của một Đề xuất.
     */
    enum ProposalState {
        Active,
        Executed,
        Canceled
    }

    /**
     * @dev Cấu trúc dữ liệu Đề xuất đã được tối ưu hóa Gas (Payload Hash Pattern).
     * Loại bỏ biến string để giảm thiểu chi phí lưu trữ EVM.
     */
    struct Proposal {
        uint256 id;                         // ID định danh duy nhất của đề xuất
        ProposalType proposalType;           // Loại đề xuất
        address target;                     // Địa chỉ đích chịu tác động (nhân sự)
        uint8 role;                         // Vai trò cần cấp (nếu cập nhật profile)
        bytes32 metadataHash;               // Keccak256 hash của (name, phone, avatar) - Payload Hash Pattern
        uint48 creationTime;                // Thời điểm tạo đề xuất (để check checkpoint)
        uint48 endTime;                     // Thời điểm kết thúc biểu quyết (packed)
        uint32 yesVotes;                    // Số lượng phiếu thuận (packed)
        uint32 noVotes;                     // Số lượng phiếu chống (packed)
        uint32 totalVotersAtCreation;       // Snapshot tổng số cử tri tại thời điểm tạo đề xuất (packed)
        ProposalState state;                // Trạng thái hiện tại của đề xuất
        address creator;                    // Người tạo đề xuất
    }
}
