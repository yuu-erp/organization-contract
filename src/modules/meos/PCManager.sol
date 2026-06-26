// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BranchContextUpgradeable} from "../base/BranchContextUpgradeable.sol";
import {ModuleKeys} from "../../core/constants/ModuleKeys.sol";

/**
 * @title PCManager
 * @dev Hợp đồng con quản lý máy trạm của module MEOS.
 */
contract PCManager is BranchContextUpgradeable {
    uint256 public activePCs;

    // Hằng số quyền này chỉ có ý nghĩa khi đi kèm với ModuleKeys.MODULE_MEOS
    uint256 public constant PERM_MEOS_PC_MANAGER = 1 << 0;
    uint256 public constant PERM_MEOS_VIP_SETTING = 1 << 1;

    function initialize(uint48 _branchId, uint48 _orgId, address _branchModuleManager) external initializer {
        __BranchContext_init(_branchId, _orgId, _branchModuleManager);
    }

    function addPC()
        external
        onlyIfModuleEnabled(ModuleKeys.MODULE_MEOS)
        requiresModulePermission(ModuleKeys.MODULE_MEOS, PERM_MEOS_PC_MANAGER)
    {
        activePCs++;
    }
}
