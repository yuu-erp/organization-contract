// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BranchContextUpgradeable} from "../base/BranchContextUpgradeable.sol";
import {ModuleKeys} from "../../core/constants/ModuleKeys.sol";

/**
 * @title POSManager
 * @dev Hợp đồng con quản lý đơn hàng/POS của module IQR.
 */
contract POSManager is BranchContextUpgradeable {
    uint256 public totalOrders;

    function initialize(uint48 _branchId, uint48 _orgId, address _branchModuleManager) external initializer {
        __BranchContext_init(_branchId, _orgId, _branchModuleManager);
    }

    function createOrder() external onlyIfModuleEnabled(ModuleKeys.MODULE_IQR) {
        totalOrders++;
    }
}
