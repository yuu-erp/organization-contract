// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IOrganizationManager} from "./interfaces/IOrganizationManager.sol";
import {IBranchStaffManager} from "./interfaces/IBranchStaffManager.sol";

/**
 * @title BranchStaffManager
 * @dev Hợp đồng con quản lý nhân sự tại chi nhánh.
 * Áp dụng kiến trúc Phân mảnh Quyền (Namespaced Permissions) bằng Bitmask.
 */
contract BranchStaffManager is Initializable, IBranchStaffManager {
    // --- Tối ưu Storage Packing (256 bits = 1 Slot) ---
    address public organizationManager; // 160 bits
    uint48 public branchId; // 48 bits
    uint48 public orgId; // 48 bits

    // Định nghĩa Role nội bộ bằng uint8
    uint8 public constant ROLE_CO_OWNER = 1;
    uint8 public constant ROLE_MANAGER = 2;
    uint8 public constant ROLE_STAFF = 3;

    // --- 1. GLOBAL PERMISSIONS (Quyền dùng chung cho mọi module) ---
    // Vd: Thu ngân, Xem báo cáo tổng, v.v.
    uint248 public constant GLOBAL_PERM_CASHIER = 1 << 0;
    uint248 public constant GLOBAL_PERM_REPORTS = 1 << 1;

    // Tối ưu Storage: Gom Role và Global Perms vào 1 Slot
    struct StaffProfile {
        uint8 role; // 8 bits
        uint248 globalPerms; // 248 bits
        // Tổng: 256 bits
    }

    // Lưu trữ hồ sơ nhân sự (Role + Global Permissions)
    mapping(address => StaffProfile) public staffProfiles;

    // --- 2. MODULE PERMISSIONS (Quyền riêng theo từng Module) ---
    // userAddress => moduleKey => bitmask quyền
    mapping(address => mapping(bytes32 => uint256)) public modulePerms;

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

    /**
     * @dev Modifier kiểm tra quyền quản trị nội bộ của nhánh
     */
    modifier requiresRole(uint8 minimumRole) {
        if (!_hasRoleOrHigher(msg.sender, minimumRole)) {
            revert Unauthorized();
        }
        _;
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
    ) external requiresRole(ROLE_MANAGER) {
        // Co-owner hoặc Manager mới được tạo Staff

        if (moduleKeys.length != modulePermBitmasks.length) {
            revert Unauthorized(); // Hoặc tạo custom error LengthMismatch
        }

        // 1. Cấp Role Staff và Global Perms
        staffProfiles[staff] = StaffProfile({role: ROLE_STAFF, globalPerms: globalPerms});

        // 2. Lặp qua mảng để cấp quyền cho từng module (MEOS, IQR...)
        for (uint256 i = 0; i < moduleKeys.length; i++) {
            modulePerms[staff][moduleKeys[i]] = modulePermBitmasks[i];
        }
    }

    /**
     * @dev Gán quyền Role và Global Permissions cho nhân sự.
     * Yêu cầu người gọi từ CO_OWNER trở lên.
     */
    function setGlobalProfile(address staff, uint8 role, uint248 globalPerms) external requiresRole(ROLE_CO_OWNER) {
        if (role == 0 || role > ROLE_STAFF) revert InvalidRole();

        // Chỉ STAFF mới cần bitmask, các cấp quản lý bypass hết nên không cần gán bit
        uint248 assignedPerms = (role == ROLE_STAFF) ? globalPerms : 0;

        staffProfiles[staff] = StaffProfile({role: role, globalPerms: assignedPerms});
    }

    /**
     * @dev Gán quyền riêng biệt cho một Module cụ thể (vd: MEOS).
     * Yêu cầu người gọi từ MANAGER trở lên.
     */
    function setModulePermissions(address staff, bytes32 moduleKey, uint256 permissions)
        external
        requiresRole(ROLE_MANAGER)
    {
        // Phải có hồ sơ (role != 0) thì mới được cấp quyền cấp module
        if (staffProfiles[staff].role == 0) revert Unauthorized();

        modulePerms[staff][moduleKey] = permissions;
    }

    /**
     * @dev Xóa toàn bộ hồ sơ nhân sự.
     */
    function revokeRole(address staff) external requiresRole(ROLE_CO_OWNER) {
        delete staffProfiles[staff];
        // Lưu ý: Không cần loop qua mapping `modulePerms` để xóa nhằm tiết kiệm Gas.
        // Khi `staffProfiles[staff].role` bằng 0, mọi hàm check quyền bên dưới sẽ tự động fail.
    }

    // ====== GIAO TIẾP VỚI CÁC SUB-CONTRACTS ======

    /**
     * @dev Check quyền DÙNG CHUNG (Thu ngân, Báo cáo).
     */
    function hasGlobalPermission(address account, uint256 permissionBit) external view override returns (bool) {
        if (_isOwnerOrManager(account)) return true;

        StaffProfile memory profile = staffProfiles[account];
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

        return (staffProfiles[account].role == ROLE_STAFF) && ((modulePerms[account][moduleKey] & permissionBit) != 0);
    }

    // ====== INTERNAL LOGIC ======

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
        // 1. Owner của Tổ chức (Bypass tuyệt đối mọi quyền)
        uint48 senderOrg = IOrganizationManager(organizationManager).getOrganizationIdByOwner(account);
        if (senderOrg == orgId) return true;

        // 2. Quyền phân cấp tại nhánh
        uint8 role = staffProfiles[account].role;
        if (role != 0 && role <= minimumRole) return true;

        return false;
    }
}
