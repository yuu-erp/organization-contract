// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IOrganizationManager} from "./interfaces/IOrganizationManager.sol";
import {IBranchStaffManager} from "./interfaces/IBranchStaffManager.sol";
import {BranchStaffManagerStorage} from "./storage/BranchStaffManagerStorage.sol";

interface IOrganizationManagerWithBMM {
    function branchModuleManager() external view returns (address);
    function getOrganizationIdByOwner(address owner) external view returns (uint48);
    function organizations(uint48 id) external view returns (address owner, uint48 orgId, bool active, bool exists);
}

/**
 * @title BranchStaffManager
 * @dev Hợp đồng con quản lý nhân sự tại chi nhánh.
 * Áp dụng kiến trúc Phân mảnh Quyền (Namespaced Permissions) bằng Bitmask.
 * Tách biệt hoàn toàn phần Governance biểu quyết ra ngoài.
 */
contract BranchStaffManager is Initializable, BranchStaffManagerStorage, IBranchStaffManager {
    using EnumerableSet for EnumerableSet.AddressSet;

    // ====== CUSTOM ERRORS ======
    error Unauthorized();
    error InvalidRole();

    /**
     * @dev Khởi tạo contract.
     */
    function initialize(uint48 _branchId, uint48 _orgId, address _organizationManager) external initializer {
        branchId = _branchId;
        orgId = _orgId;
        organizationManager = _organizationManager;
    }

    // ====== THIẾT LẬP ĐỊA CHỈ GOVERNANCE ======
    
    /**
     * @dev Thiết lập địa chỉ BranchGovernanceManager đặc quyền.
     * Chỉ cho phép BranchModuleManager gọi để tránh phụ thuộc vòng.
     */
    function setBranchGovernanceManager(address _govManager) external {
        address bmm = IOrganizationManagerWithBMM(organizationManager).branchModuleManager();
        if (msg.sender != bmm) revert Unauthorized();
        branchGovernanceManager = _govManager;
    }

    function setStaffMetadataRegistry(address _registry) external {
        address owner = _getOrgOwner();
        address bmm = IOrganizationManagerWithBMM(organizationManager).branchModuleManager();
        if (msg.sender != owner && msg.sender != bmm) revert Unauthorized();
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
    ) external override {
        uint8 currentRole = _staffProfiles[staff].role;
        bool isTargetCoOwnerOrManager = (currentRole == ROLE_CO_OWNER || currentRole == ROLE_MANAGER);

        // Guardrail 5: Bắt buộc phải thông qua Proposal nếu target là co-owner/manager và coOwnerCount > 0
        if (isTargetCoOwnerOrManager && _coOwners.length() > 0) {
            require(msg.sender == branchGovernanceManager, "RequiresProposal");
        } else {
            // Check quyền Manager thông thường
            if (!_hasRoleOrHigher(msg.sender, ROLE_MANAGER)) revert Unauthorized();
        }

        if (moduleKeys.length != modulePermBitmasks.length) {
            revert Unauthorized();
        }

        _staffProfiles[staff] = StaffProfile({role: ROLE_STAFF, globalPerms: globalPerms});

        for (uint256 i = 0; i < moduleKeys.length; i++) {
            _modulePerms[staff][moduleKeys[i]] = modulePermBitmasks[i];
        }
    }

    /**
     * @dev Gán quyền Role và Global Permissions cho nhân sự.
     */
    function setGlobalProfile(address staff, uint8 role, uint248 globalPerms) external override {
        uint8 currentRole = _staffProfiles[staff].role;
        bool isTargetCoOwnerOrManager = (
            currentRole == ROLE_CO_OWNER || currentRole == ROLE_MANAGER ||
            role == ROLE_CO_OWNER || role == ROLE_MANAGER
        );

        // Guardrail 5: Chặn và yêu cầu proposal nếu target là co-owner/manager
        if (isTargetCoOwnerOrManager && _coOwners.length() > 0) {
            require(msg.sender == branchGovernanceManager, "RequiresProposal");
        } else {
            if (!_hasRoleOrHigher(msg.sender, ROLE_CO_OWNER)) revert Unauthorized();
        }

        if (role == 0 || role > ROLE_STAFF) revert InvalidRole();

        _updateCoOwnerSet(staff, role);

        uint248 assignedPerms = (role == ROLE_STAFF) ? globalPerms : 0;
        _staffProfiles[staff] = StaffProfile({role: role, globalPerms: assignedPerms});
    }

    /**
     * @dev Gán quyền riêng biệt cho một Module cụ thể (vd: MEOS).
     */
    function setModulePermissions(address staff, bytes32 moduleKey, uint256 permissions) external override {
        uint8 currentRole = _staffProfiles[staff].role;
        bool isTargetCoOwnerOrManager = (currentRole == ROLE_CO_OWNER || currentRole == ROLE_MANAGER);

        // Guardrail 5: Chặn và yêu cầu proposal nếu target là co-owner/manager
        if (isTargetCoOwnerOrManager && _coOwners.length() > 0) {
            require(msg.sender == branchGovernanceManager, "RequiresProposal");
        } else {
            if (!_hasRoleOrHigher(msg.sender, ROLE_MANAGER)) revert Unauthorized();
        }

        if (_staffProfiles[staff].role == 0) revert Unauthorized();
        _modulePerms[staff][moduleKey] = permissions;
    }

    /**
     * @dev Xóa toàn bộ hồ sơ nhân sự.
     */
    function revokeRole(address staff) external override {
        uint8 currentRole = _staffProfiles[staff].role;
        bool isTargetCoOwnerOrManager = (currentRole == ROLE_CO_OWNER || currentRole == ROLE_MANAGER);

        // Guardrail 5: Chặn và yêu cầu proposal nếu target là co-owner/manager
        if (isTargetCoOwnerOrManager && _coOwners.length() > 0) {
            require(msg.sender == branchGovernanceManager, "RequiresProposal");
        } else {
            if (!_hasRoleOrHigher(msg.sender, ROLE_CO_OWNER)) revert Unauthorized();
        }

        if (_staffProfiles[staff].role == ROLE_CO_OWNER) {
            _coOwners.remove(staff);
        }

        delete _staffProfiles[staff];
    }

    // ====== VIEW FUNCTIONS ======

    function coOwnerCount() external view override returns (uint256) {
        return _coOwners.length();
    }

    function isCoOwner(address account) external view override returns (bool) {
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

        return (_staffProfiles[account].role == ROLE_STAFF) && ((_modulePerms[account][moduleKey] & permissionBit) != 0);
    }

    // ====== INTERNAL LOGIC ======

    function _getOrgOwner() internal view returns (address) {
        (address owner, , , ) = IOrganizationManagerWithBMM(organizationManager).organizations(orgId);
        return owner;
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
        uint48 senderOrg = IOrganizationManagerWithBMM(organizationManager).getOrganizationIdByOwner(account);
        if (senderOrg == orgId) return true;

        uint8 role = _staffProfiles[account].role;
        if (role != 0 && role <= minimumRole) return true;

        return false;
    }

    function modulePerms(address staff, bytes32 moduleKey) external view override returns (uint256) {
        return _modulePerms[staff][moduleKey];
    }
}
