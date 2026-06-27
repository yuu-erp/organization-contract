// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @dev Interface dùng để các sub-contracts (PCManager, AccountManager)
 * gọi ngược lên BranchStaffManager để check quyền, quản lý vai trò và truy vấn thông tin cử tri.
 */
interface IBranchStaffManager {
    function addStaffWithPermissions(
        address staff,
        uint248 globalPerms,
        bytes32[] calldata moduleKeys,
        uint256[] calldata modulePermBitmasks
    ) external;

    function hasGlobalPermission(address account, uint256 permissionBit) external view returns (bool);

    function hasModulePermission(address account, bytes32 moduleKey, uint256 permissionBit) external view returns (bool);

    // ====== CÁC HÀM MỚI BỔ SUNG CHO HỆ THỐNG VOTING ======
    function coOwnerCount() external view returns (uint256);

    function isCoOwner(address account) external view returns (bool);

    function staffProfiles(address staff) external view returns (uint8 role, uint248 globalPerms);

    function setGlobalProfile(address staff, uint8 role, uint248 globalPerms) external;

    function setModulePermissions(address staff, bytes32 moduleKey, uint256 permissions) external;

    function revokeRole(address staff) external;

    function setStaffMetadataRegistry(address _registry) external;
}
