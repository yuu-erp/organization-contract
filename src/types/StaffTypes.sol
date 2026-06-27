// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title StaffTypes
 * @dev Định nghĩa các kiểu dữ liệu hiển thị (Metadata) của nhân sự.
 */
library StaffTypes {
    struct StaffMetadata {
        string name;
        string phoneNumber;
        string avatar;
    }
}
