// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ModuleKeys
 * @dev Hằng số định danh cho từng module trong hệ thống.
 *      Sử dụng bytes32 để tối ưu gas khi dùng làm mapping key.
 */
library ModuleKeys {
    bytes32 public constant MODULE_MEOS = keccak256("MODULE_MEOS");
    bytes32 public constant MODULE_IQR = keccak256("MODULE_IQR");
    bytes32 public constant MODULE_LOYALTY = keccak256("MODULE_LOYALTY");
}
