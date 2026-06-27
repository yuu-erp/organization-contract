// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IBranchStaffManager
 * @dev Giao diện quản trị vai trò (RBAC) và phân quyền chi nhánh.
 */
interface IBranchStaffManager {
    
    // ====== CUSTOM ERRORS ======
    error RequiresProposal();

    // ====== WRITE FUNCTIONS (ADMINISTRATIVE ACTIONS) ======

    /**
     * @dev Thêm STAFF và cấp toàn bộ quyền trong một giao dịch.
     */
    function addStaffWithPermissions(
        address staff,
        uint248 globalPerms,
        bytes32[] calldata moduleKeys,
        uint256[] calldata modulePermBitmasks
    ) external;

    /**
     * @dev Thiết lập vai trò và quyền toàn cục cho một tài khoản.
     */
    function setGlobalProfile(address staff, uint8 role, uint248 globalPerms) external;

    /**
     * @dev Thiết lập quyền hạn riêng biệt cho từng Module cụ thể.
     */
    function setModulePermissions(address staff, bytes32 moduleKey, uint256 permissions) external;

    /**
     * @dev Thu hồi vai trò và xoá bỏ hồ sơ nhân sự.
     */
    function revokeRole(address staff) external;

    /**
     * @dev Liên kết địa chỉ BranchGovernanceManager của chi nhánh (Lazy-Binding).
     * Chỉ cho phép BranchModuleManager gọi để tránh phụ thuộc vòng.
     */
    function setBranchGovernanceManager(address _governanceManager) external;

    /**
     * @dev Thiết lập địa chỉ StaffMetadataRegistry cho chi nhánh.
     */
    function setStaffMetadataRegistry(address _registry) external;

    // ====== READ GETTERS ======

    /**
     * @dev Lấy thông tin hồ sơ (vai trò, quyền toàn cục) của nhân sự.
     */
    function staffProfiles(address staff) external view returns (uint8 role, uint248 globalPerms);

    /**
     * @dev Lấy bitmask quyền hạn của một module cụ thể đối với một nhân sự.
     */
    function modulePerms(address staff, bytes32 moduleKey) external view returns (uint256);

    /**
     * @dev Trả về số lượng Co-owner hiện có tại chi nhánh.
     */
    function coOwnerCount() external view returns (uint256);

    /**
     * @dev Kiểm tra tài khoản có phải là Co-owner của chi nhánh không.
     */
    function isCoOwner(address account) external view returns (bool);

    /**
     * @dev Kiểm tra quyền toàn cục dùng chung.
     */
    function hasGlobalPermission(address account, uint256 permissionBit) external view returns (bool);

    /**
     * @dev Kiểm tra quyền hạn riêng biệt của module.
     */
    function hasModulePermission(address account, bytes32 moduleKey, uint256 permissionBit) external view returns (bool);
}
