// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @dev Interface dùng để các sub-contracts (PCManager, AccountManager)
 * gọi ngược lên BranchStaffManager để check quyền.
 */
interface IBranchStaffManager {
    function hasGlobalPermission(
        address account,
        uint256 permissionBit
    ) external view returns (bool);

    function hasModulePermission(
        address account,
        bytes32 moduleKey,
        uint256 permissionBit
    ) external view returns (bool);
}
