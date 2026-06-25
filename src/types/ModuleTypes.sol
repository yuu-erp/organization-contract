// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ModuleTypes
 * @dev Centralized type definitions for Module domain.
 *      Used across ModuleRegistry, BranchModuleManager, and factories.
 */
library ModuleTypes {
    /**
     * @dev Định nghĩa một loại module trong hệ thống.
     * @param key Định danh duy nhất (VD: MODULE_MEOS)
     * @param name Tên hiển thị (VD: "MEOS")
     * @param factory Địa chỉ factory contract deploy bundle
     * @param active Module có đang hoạt động không
     * @param exists Đã được đăng ký chưa
     */
    struct ModuleDefinition {
        bytes32 key;
        string name;
        address factory;
        bool active;
        bool exists;
    }
}
