// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title RoleHashes
 * @dev Lưu trữ các hằng số định danh quyền (Role) cho hệ thống AccessControl.
 */
library RoleHashes {
    // Quyền tối cao (Owner) - Mặc định của OpenZeppelin
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
    // Quyền dành cho Đội ngũ Developer (Nâng cấp module)
    bytes32 public constant OPS_ADMIN_ROLE = keccak256("OPS_ADMIN_ROLE");
    // Quyền dành cho Đội ngũ Vận hành/Sale (Tạo tổ chức, cấp phép module)
    bytes32 public constant PLATFORM_ADMIN_ROLE =
        keccak256("PLATFORM_ADMIN_ROLE");
}
