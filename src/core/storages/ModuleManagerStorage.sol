// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ModuleConfig} from "../../shared/types/DataTypes.sol";
import {ISystemAccessControl} from "../interfaces/ISystemAccessControl.sol";
import {IModuleManager} from "../interfaces/IModuleManager.sol";

/**
 * @title ModuleManagerStorage
 * @dev Nơi lưu trữ trạng thái đăng ký và phân quyền của các module hệ thống.
 */
abstract contract ModuleManagerStorage is IModuleManager {
    ISystemAccessControl public accessControl;

    // CẤU TRÚC MỚI: parentId => subId => Config
    mapping(bytes32 => mapping(bytes32 => ModuleConfig)) public subModules;

    // Phân quyền theo Module Cha (ví dụ: cấp quyền IQR thì được quản lý cả MENU/ORDER)
    mapping(bytes32 => mapping(address => bool)) public moduleAdmins;

    uint256[50] private __gap;
}
