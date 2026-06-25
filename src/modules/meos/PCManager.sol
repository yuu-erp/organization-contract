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

    function initialize(
        uint256 _branchId,
        uint256 _orgId,
        address _branchModuleManager
    ) external initializer {
        __BranchContext_init(_branchId, _orgId, _branchModuleManager);
    }

    function addPC() external onlyIfModuleEnabled(ModuleKeys.MODULE_MEOS) {
        activePCs++;
    }
}
