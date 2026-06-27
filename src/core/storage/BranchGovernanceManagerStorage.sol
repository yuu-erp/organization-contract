// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {GovernanceTypes} from "../../types/GovernanceTypes.sol";

/**
 * @title BranchGovernanceManagerStorage
 * @dev Định nghĩa bố cục bộ nhớ (Storage Layout) cho BranchGovernanceManager để đảm bảo an toàn khi nâng cấp Proxy.
 */
abstract contract BranchGovernanceManagerStorage {
    
    // --- State Variables ---
    uint48 public branchId;
    uint48 public orgId;
    address public organizationManager;
    address public branchStaffManager;
    address public staffMetadataRegistry;

    // Quản lý đề xuất và phiếu bầu
    mapping(uint256 => GovernanceTypes.Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public proposalVoted;
    uint256 public proposalCounter;

    /**
     * @dev Khoảng trống dự phòng để mở rộng các biến storage sau này.
     */
    uint256[42] private __gap;
}
