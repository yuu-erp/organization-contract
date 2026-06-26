// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BranchContextUpgradeable} from "../base/BranchContextUpgradeable.sol";
import {ModuleKeys} from "../../core/constants/ModuleKeys.sol";

/**
 * @title AccountManager
 * @dev Hợp đồng con quản lý tài khoản người dùng/hội viên của module MEOS.
 */
contract AccountManager is BranchContextUpgradeable {
    mapping(string => address) public usernameToWallet;

    function initialize(uint48 _branchId, uint48 _orgId, address _branchModuleManager) external initializer {
        __BranchContext_init(_branchId, _orgId, _branchModuleManager);
    }

    function registerUser(string calldata username, address wallet)
        external
        onlyIfModuleEnabled(ModuleKeys.MODULE_MEOS)
    {
        usernameToWallet[username] = wallet;
    }
}
