// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @dev Interface dùng để các sub-contracts (PCManager, AccountManager)
 * gọi ngược lên BranchStaffManager để check quyền.
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
}
