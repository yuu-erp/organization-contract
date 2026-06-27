// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IOrganizationManager} from "./interfaces/IOrganizationManager.sol";
import {IBranchStaffManager} from "./interfaces/IBranchStaffManager.sol";
import {BranchStaffManagerStorage, ProposalType, ProposalState} from "./storage/BranchStaffManagerStorage.sol";

interface IOrganizationManagerWithOwner {
    function organizations(uint48 id) external view returns (address owner, uint48 orgId, bool active, bool exists);
}

interface IStaffMetadataRegistry {
    function setStaffMetadata(
        uint48 branchId,
        address staff,
        string calldata name,
        string calldata phoneNumber,
        string calldata avatar
    ) external;
}

/**
 * @title BranchStaffManager
 * @dev Hợp đồng con quản lý nhân sự tại chi nhánh.
 * Áp dụng kiến trúc Phân mảnh Quyền (Namespaced Permissions) bằng Bitmask.
 * Tích hợp cơ chế Quản trị (Decentralized Voting) cho các thay đổi nhân sự cấp cao.
 */
contract BranchStaffManager is Initializable, BranchStaffManagerStorage, IBranchStaffManager {
    using EnumerableSet for EnumerableSet.AddressSet;

    // ====== EVENTS ======
    event ProposalCreated(uint256 indexed proposalId, ProposalType indexed proposalType, address indexed target);
    event Voted(uint256 indexed proposalId, address indexed voter, bool support);
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCanceled(uint256 indexed proposalId);

    // ====== CUSTOM ERRORS ======
    error Unauthorized();
    error InvalidRole();
    error RequiresProposal(); // Guardrail 5
    error InvalidProposal();
    error ProposalNotActive();
    error ProposalAlreadyVoted();
    error ProposalCannotBeExecuted();
    error ProposalExpired();

    /**
     * @dev Khởi tạo contract.
     */
    function initialize(uint48 _branchId, uint48 _orgId, address _organizationManager) external initializer {
        branchId = _branchId;
        orgId = _orgId;
        organizationManager = _organizationManager;
    }

    /**
     * @dev Modifier kiểm tra quyền quản trị nội bộ của nhánh
     */
    modifier requiresRole(uint8 minimumRole) {
        if (!_hasRoleOrHigher(msg.sender, minimumRole)) {
            revert Unauthorized();
        }
        _;
    }

    // ====== CẤT ĐẶT ĐỊA CHỈ TRUY CẬP ======
    function setStaffMetadataRegistry(address _registry) external {
        address owner = _getOrgOwner();
        if (msg.sender != owner) revert Unauthorized();
        staffMetadataRegistry = _registry;
    }

    // ====== QUẢN LÝ NHÂN SỰ VÀ QUYỀN ======

    /**
     * @dev Hàm tiện ích cho Frontend: Thêm STAFF và cấp toàn quyền (Global + Module) trong 1 Transaction duy nhất.
     */
    function addStaffWithPermissions(
        address staff,
        uint248 globalPerms,
        bytes32[] calldata moduleKeys,
        uint256[] calldata modulePermBitmasks
    ) external override requiresRole(ROLE_MANAGER) {
        // Guardrail 5: Kiểm tra nếu target hiện tại là Co-owner hoặc Manager
        if (!_executingProposal && _coOwners.length() > 0) {
            uint8 currentRole = _staffProfiles[staff].role;
            if (currentRole == ROLE_CO_OWNER || currentRole == ROLE_MANAGER) {
                revert RequiresProposal();
            }
        }

        if (moduleKeys.length != modulePermBitmasks.length) {
            revert Unauthorized();
        }

        _staffProfiles[staff] = StaffProfile({role: ROLE_STAFF, globalPerms: globalPerms});

        for (uint256 i = 0; i < moduleKeys.length; i++) {
            modulePerms[staff][moduleKeys[i]] = modulePermBitmasks[i];
        }
    }

    /**
     * @dev Gán quyền Role và Global Permissions cho nhân sự.
     */
    function setGlobalProfile(address staff, uint8 role, uint248 globalPerms) external requiresRole(ROLE_CO_OWNER) {
        _setGlobalProfile(staff, role, globalPerms);
    }

    function _setGlobalProfile(address staff, uint8 role, uint248 globalPerms) internal {
        // Guardrail 5: Nếu target là Co-owner/Manager, hoặc chuẩn bị set thành Co-owner/Manager,
        // và coOwnerCount > 0, bắt buộc phải thông qua proposal.
        if (!_executingProposal && _coOwners.length() > 0) {
            uint8 currentRole = _staffProfiles[staff].role;
            if (
                currentRole == ROLE_CO_OWNER || currentRole == ROLE_MANAGER ||
                role == ROLE_CO_OWNER || role == ROLE_MANAGER
            ) {
                revert RequiresProposal();
            }
        }

        if (role == 0 || role > ROLE_STAFF) revert InvalidRole();

        _updateCoOwnerSet(staff, role);

        uint248 assignedPerms = (role == ROLE_STAFF) ? globalPerms : 0;
        _staffProfiles[staff] = StaffProfile({role: role, globalPerms: assignedPerms});
    }

    /**
     * @dev Gán quyền riêng biệt cho một Module cụ thể (vd: MEOS).
     */
    function setModulePermissions(address staff, bytes32 moduleKey, uint256 permissions)
        external
        requiresRole(ROLE_MANAGER)
    {
        _setModulePermissions(staff, moduleKey, permissions);
    }

    function _setModulePermissions(address staff, bytes32 moduleKey, uint256 permissions) internal {
        // Guardrail 5: Chặn nếu target đang là Co-owner hoặc Manager
        if (!_executingProposal && _coOwners.length() > 0) {
            uint8 currentRole = _staffProfiles[staff].role;
            if (currentRole == ROLE_CO_OWNER || currentRole == ROLE_MANAGER) {
                revert RequiresProposal();
            }
        }

        if (_staffProfiles[staff].role == 0) revert Unauthorized();
        modulePerms[staff][moduleKey] = permissions;
    }

    /**
     * @dev Xóa toàn bộ hồ sơ nhân sự.
     */
    function revokeRole(address staff) external requiresRole(ROLE_CO_OWNER) {
        _revokeRole(staff);
    }

    function _revokeRole(address staff) internal {
        // Guardrail 5: Chặn nếu target đang là Co-owner hoặc Manager
        if (!_executingProposal && _coOwners.length() > 0) {
            uint8 currentRole = _staffProfiles[staff].role;
            if (currentRole == ROLE_CO_OWNER || currentRole == ROLE_MANAGER) {
                revert RequiresProposal();
            }
        }

        if (_staffProfiles[staff].role == ROLE_CO_OWNER) {
            _coOwners.remove(staff);
        }

        delete _staffProfiles[staff];
    }

    // ====== HÀM QUẢN TRỊ & BỎ PHIẾU (VOTING FUNCTIONS) ======

    /**
     * @dev Tạo đề xuất (Proposal) thay đổi nhân sự/quyền hạn/metadata.
     */
    function createProposal(
        ProposalType proposalType,
        address target,
        uint8 role,
        uint248 globalPerms,
        bytes32 moduleKey,
        uint256 modulePermBitmask,
        string calldata name,
        string calldata phone,
        string calldata avatar
    ) external returns (uint256) {
        if (!_isEligoter(msg.sender)) revert Unauthorized();

        uint256 proposalId = ++proposalCounter;
        uint256 totalVoters = _getTotalVotersCount(); // Lấy tổng số cử tri tại thời điểm tạo

        proposals[proposalId] = Proposal({
            id: proposalId,
            proposalType: proposalType,
            target: target,
            role: role,
            globalPerms: globalPerms,
            moduleKey: moduleKey,
            modulePerms: modulePermBitmask,
            metadataName: name,
            metadataPhone: phone,
            metadataAvatar: avatar,
            endTime: block.timestamp + VOTING_DURATION, // Guardrail 1
            yesVotes: 0,
            noVotes: 0,
            totalVotersAtCreation: totalVoters, // Guardrail 3: Voter Snapshotting
            state: ProposalState.Active, // Guardrail 2
            creator: msg.sender
        });

        emit ProposalCreated(proposalId, proposalType, target);
        return proposalId;
    }

    /**
     * @dev Bỏ phiếu cho Proposal.
     */
    function voteProposal(uint256 proposalId, bool support) external {
        Proposal storage proposal = proposals[proposalId];
        if (proposal.state != ProposalState.Active) revert ProposalNotActive(); // Guardrail 2
        if (block.timestamp > proposal.endTime) revert ProposalExpired(); // Guardrail 1
        if (!_isEligoter(msg.sender)) revert Unauthorized();
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
     * @dev Thực thi Proposal đã đạt đa số phiếu thuận.
     */
    function executeProposal(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        if (proposal.state != ProposalState.Active) revert ProposalNotActive();

        // Guardrail 3: Điều kiện duyệt dựa trên snapshot của totalVotersAtCreation
        if (proposal.yesVotes <= (proposal.totalVotersAtCreation / 2)) {
            revert ProposalCannotBeExecuted();
        }

        proposal.state = ProposalState.Executed;
        _executingProposal = true; // Kích hoạt flag bypass Guard Clause

        if (proposal.proposalType == ProposalType.AddOrUpdateProfile) {
            _setGlobalProfile(proposal.target, proposal.role, proposal.globalPerms);
        } else if (proposal.proposalType == ProposalType.RevokeRole) {
            _revokeRole(proposal.target);
        } else if (proposal.proposalType == ProposalType.SetModulePermissions) {
            _setModulePermissions(proposal.target, proposal.moduleKey, proposal.modulePerms);
        } else if (proposal.proposalType == ProposalType.UpdateMetadata) {
            if (staffMetadataRegistry == address(0)) revert InvalidProposal();
            IStaffMetadataRegistry(staffMetadataRegistry).setStaffMetadata(
                branchId,
                proposal.target,
                proposal.metadataName,
                proposal.metadataPhone,
                proposal.metadataAvatar
            );
        }

        _executingProposal = false; // Tắt flag bypass
        emit ProposalExecuted(proposalId);
    }

    /**
     * @dev Hủy Proposal đang Active.
     */
    function cancelProposal(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        if (proposal.state != ProposalState.Active) revert ProposalNotActive(); // Guardrail 2

        address owner = _getOrgOwner();
        if (msg.sender != proposal.creator && msg.sender != owner) revert Unauthorized();

        proposal.state = ProposalState.Canceled;
        emit ProposalCanceled(proposalId);
    }

    // ====== VIEW FUNCTIONS ======

    function coOwnerCount() external view returns (uint256) {
        return _coOwners.length();
    }

    function isCoOwner(address account) external view returns (bool) {
        return _coOwners.contains(account);
    }

    function staffProfiles(address staff) external view override returns (uint8 role, uint248 globalPerms) {
        StaffProfile memory profile = _staffProfiles[staff];
        return (profile.role, profile.globalPerms);
    }

    // ====== GIAO TIẾP VỚI CÁC SUB-CONTRACTS ======

    /**
     * @dev Check quyền DÙNG CHUNG (Thu ngân, Báo cáo).
     */
    function hasGlobalPermission(address account, uint256 permissionBit) external view override returns (bool) {
        if (_isOwnerOrManager(account)) return true;

        StaffProfile memory profile = _staffProfiles[account];
        return (profile.role == ROLE_STAFF) && ((profile.globalPerms & permissionBit) != 0);
    }

    /**
     * @dev Check quyền RIÊNG CỦA MODULE (Ví dụ: Quyền quản lý PC của MEOS).
     */
    function hasModulePermission(address account, bytes32 moduleKey, uint256 permissionBit)
        external
        view
        override
        returns (bool)
    {
        if (_isOwnerOrManager(account)) return true;

        return (_staffProfiles[account].role == ROLE_STAFF) && ((modulePerms[account][moduleKey] & permissionBit) != 0);
    }

    // ====== INTERNAL LOGIC ======

    function _getOrgOwner() internal view returns (address) {
        (address owner, , , ) = IOrganizationManagerWithOwner(organizationManager).organizations(orgId);
        return owner;
    }

    function _getTotalVotersCount() internal view returns (uint256) {
        address owner = _getOrgOwner();
        uint256 count = _coOwners.length();
        if (_coOwners.contains(owner)) {
            return count;
        } else {
            return count + 1;
        }
    }

    function _isEligoter(address account) internal view returns (bool) {
        if (account == _getOrgOwner()) return true;
        return _coOwners.contains(account);
    }

    function _updateCoOwnerSet(address staff, uint8 newRole) internal {
        uint8 oldRole = _staffProfiles[staff].role;
        if (oldRole == ROLE_CO_OWNER && newRole != ROLE_CO_OWNER) {
            _coOwners.remove(staff);
        } else if (oldRole != ROLE_CO_OWNER && newRole == ROLE_CO_OWNER) {
            _coOwners.add(staff);
        }
    }

    /**
     * @dev Kiểm tra tài khoản có phải Owner (Tổ chức) hoặc Quản lý cấp cao (Nhánh) không.
     */
    function _isOwnerOrManager(address account) internal view returns (bool) {
        return _hasRoleOrHigher(account, ROLE_MANAGER);
    }

    /**
     * @dev Logic cốt lõi để check Role phân cấp.
     */
    function _hasRoleOrHigher(address account, uint8 minimumRole) internal view returns (bool) {
        uint48 senderOrg = IOrganizationManager(organizationManager).getOrganizationIdByOwner(account);
        if (senderOrg == orgId) return true;

        uint8 role = _staffProfiles[account].role;
        if (role != 0 && role <= minimumRole) return true;

        return false;
    }
}
