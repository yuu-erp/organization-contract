// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BranchContextUpgradeable} from "../base/BranchContextUpgradeable.sol";
import {ModuleKeys} from "../../core/constants/ModuleKeys.sol";

/**
 * @title PointManager
 * @dev Hợp đồng con quản lý điểm thưởng của module Loyalty.
 */
contract PointManager is BranchContextUpgradeable {
    mapping(address => uint256) public userPoints;

    function initialize(uint48 _branchId, uint48 _orgId, address _branchModuleManager) external initializer {
        __BranchContext_init(_branchId, _orgId, _branchModuleManager);
    }

    function addPoints(address user, uint256 amount) external onlyIfModuleEnabled(ModuleKeys.MODULE_LOYALTY) {
        userPoints[user] += amount;
    }
}
