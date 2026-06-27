// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IBranchGovernanceManager} from "./interfaces/IBranchGovernanceManager.sol";
import {BranchGovernanceManagerStorage} from "./storage/BranchGovernanceManagerStorage.sol";
import {GovernanceTypes} from "../types/GovernanceTypes.sol";

interface IOrganizationManagerWithOwner {
    function organizations(uint48 id) external view returns (address owner, uint48 orgId, bool active, bool exists);
}

interface IBranchStaffManagerGov {
    function coOwnerCount() external view returns (uint256);
    function isCoOwner(address account) external view returns (bool);
    
    // Các hàm thực thi (chỉ Gov mới được gọi)
    function setGlobalProfile(address staff, uint8 role, uint248 globalPerms) external;
    function setModulePermissions(address staff, bytes32 moduleKey, uint256 permissions) external;
    function revokeRole(address staff) external;
}

interface IStaffMetadataRegistryGov {
    function setStaffMetadata(
        uint48 branchId,
        address staff,
        string calldata name,
        string calldata phoneNumber,
        string calldata avatar
    ) external;
}

/**
 * @title BranchGovernanceManager
 * @dev Hợp đồng chuyên biệt xử lý đề xuất, bỏ phiếu và thực thi các hành động đặc quyền tại chi nhánh.
 */
contract BranchGovernanceManager is Initializable, BranchGovernanceManagerStorage, IBranchGovernanceManager {
    
    // ====== HẰNG SỐ ======
    uint256 public constant VOTING_DURATION = 7 days; // Guardrail 1: Hardcoded Duration

    error InvalidInput();

    /**
     * @dev Khởi tạo Proxy.
     */
    function initialize(
        uint48 _branchId,
        uint48 _orgId,
        address _organizationManager,
        address _branchStaffManager,
        address _staffMetadataRegistry
    ) external initializer {
        if (_organizationManager == address(0) || _branchStaffManager == address(0) || _staffMetadataRegistry == address(0)) {
            revert InvalidInput();
        }
        branchId = _branchId;
        orgId = _orgId;
        organizationManager = _organizationManager;
        branchStaffManager = _branchStaffManager;
        staffMetadataRegistry = _staffMetadataRegistry;
    }

    // ====== HÀM QUẢN TRỊ & BỎ PHIẾU ======

    /**
     * @dev Tạo đề xuất thay đổi nhân sự/metadata.
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
    ) external override returns (uint256) {
        if (!_isEligibleVoter(msg.sender)) revert Unauthorized();

        uint256 proposalId = ++proposalCounter;
        uint256 totalVoters = _getTotalVotersCount(); // Chụp lại số cử tri tại thời điểm tạo

        // Tính toán hash của payload metadata để lưu trữ tiết kiệm Gas
        bytes32 metadataHash = keccak256(abi.encode(name, phone, avatar));

        proposals[proposalId] = GovernanceTypes.Proposal({
            id: proposalId,
            proposalType: proposalType,
            target: target,
            role: role,
            globalPerms: globalPerms,
            moduleKey: moduleKey,
            modulePermBitmask: modulePermBitmask,
            metadataHash: metadataHash,
            endTime: uint48(block.timestamp + VOTING_DURATION),
            yesVotes: 0,
            noVotes: 0,
            totalVotersAtCreation: uint32(totalVoters),
            state: GovernanceTypes.ProposalState.Active,
            creator: msg.sender
        });

        emit ProposalCreated(proposalId, proposalType, target, name, phone, avatar);
        return proposalId;
    }

    /**
     * @dev Thực hiện bỏ phiếu.
     */
    function voteProposal(uint256 proposalId, bool support) external override {
        GovernanceTypes.Proposal storage proposal = proposals[proposalId];
        if (proposal.state != GovernanceTypes.ProposalState.Active) revert ProposalNotActive();
        if (block.timestamp > proposal.endTime) revert ProposalExpired();
        if (!_isEligibleVoter(msg.sender)) revert Unauthorized();
        if (proposalVoted[proposalId][msg.sender]) revert ProposalAlreadyVoted();

        proposalVoted[proposalId][msg.sender] = true;

        if (support) {
            proposal.yesVotes += 1;
        } else {
            proposal.noVotes += 1;
        }

        emit Voted(proposalId, msg.sender, support);
    }

    /**
     * @dev Thực thi đề xuất khi đủ phiếu thuận.
     */
    function executeProposal(
        uint256 proposalId,
        string calldata name,
        string calldata phone,
        string calldata avatar
    ) external override {
        GovernanceTypes.Proposal storage proposal = proposals[proposalId];
        if (proposal.state != GovernanceTypes.ProposalState.Active) revert ProposalNotActive();

        // Kiểm tra điều kiện đa số biểu quyết dựa trên số cử tri tại thời điểm tạo đề xuất
        if (proposal.yesVotes <= (proposal.totalVotersAtCreation / 2)) {
            revert ProposalCannotBeExecuted();
        }

        // Xác thực tính khớp của payload truyền vào với hash đã lưu
        if (keccak256(abi.encode(name, phone, avatar)) != proposal.metadataHash) {
            revert HashMismatch();
        }

        proposal.state = GovernanceTypes.ProposalState.Executed;

        // Thực thi gọi sang các contract tương ứng
        if (proposal.proposalType == GovernanceTypes.ProposalType.AddOrUpdateProfile) {
            IBranchStaffManagerGov(branchStaffManager).setGlobalProfile(
                proposal.target,
                proposal.role,
                proposal.globalPerms
            );
        } else if (proposal.proposalType == GovernanceTypes.ProposalType.RevokeRole) {
            IBranchStaffManagerGov(branchStaffManager).revokeRole(proposal.target);
        } else if (proposal.proposalType == GovernanceTypes.ProposalType.SetModulePermissions) {
            IBranchStaffManagerGov(branchStaffManager).setModulePermissions(
                proposal.target,
                proposal.moduleKey,
                proposal.modulePermBitmask
            );
        } else if (proposal.proposalType == GovernanceTypes.ProposalType.UpdateMetadata) {
            IStaffMetadataRegistryGov(staffMetadataRegistry).setStaffMetadata(
                branchId,
                proposal.target,
                name,
                phone,
                avatar
            );
        }

        emit ProposalExecuted(proposalId);
    }

    /**
     * @dev Hủy đề xuất.
     */
    function cancelProposal(uint256 proposalId) external override {
        GovernanceTypes.Proposal storage proposal = proposals[proposalId];
        if (proposal.state != GovernanceTypes.ProposalState.Active) revert ProposalNotActive();

        address owner = _getOrgOwner();
        if (msg.sender != proposal.creator && msg.sender != owner) revert Unauthorized();

        proposal.state = GovernanceTypes.ProposalState.Canceled;
        emit ProposalCanceled(proposalId);
    }

    // ====== VIEW & INTERNAL FUNCTIONS ======

    function _getOrgOwner() internal view returns (address) {
        (address owner, , , ) = IOrganizationManagerWithOwner(organizationManager).organizations(orgId);
        return owner;
    }

    function _getTotalVotersCount() internal view returns (uint256) {
        address owner = _getOrgOwner();
        uint256 count = IBranchStaffManagerGov(branchStaffManager).coOwnerCount();
        bool ownerIsCoOwner = IBranchStaffManagerGov(branchStaffManager).isCoOwner(owner);
        return ownerIsCoOwner ? count : count + 1;
    }

    function _isEligibleVoter(address account) internal view returns (bool) {
        if (account == _getOrgOwner()) return true;
        return IBranchStaffManagerGov(branchStaffManager).isCoOwner(account);
    }
}
