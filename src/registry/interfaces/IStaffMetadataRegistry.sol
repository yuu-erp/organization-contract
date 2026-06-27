// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {StaffTypes} from "../../types/StaffTypes.sol";

/**
 * @title IStaffMetadataRegistry
 * @dev Giao diện quản lý lưu trữ metadata tập trung (name, phone, avatar) của nhân sự.
 */
interface IStaffMetadataRegistry {
    
    // ====== EVENTS ======
    
    /**
     * @dev Phát ra khi metadata của nhân viên được cập nhật.
     */
    event StaffMetadataUpdated(
        uint48 indexed branchId,
        address indexed staff,
        string name,
        string phoneNumber,
        string avatar
    );

    // ====== CORE FUNCTIONS ======

    /**
     * @dev Cập nhật thông tin metadata cho nhân viên tại chi nhánh.
     * @param branchId ID của chi nhánh.
     * @param staff Địa chỉ của nhân viên.
     * @param name Tên hiển thị.
     * @param phoneNumber Số điện thoại.
     * @param avatar Đường dẫn ảnh đại diện.
     */
    function setStaffMetadata(
        uint48 branchId,
        address staff,
        string calldata name,
        string calldata phoneNumber,
        string calldata avatar
    ) external;

    /**
     * @dev Đọc thông tin metadata của nhân viên tại chi nhánh.
     * @param branchId ID của chi nhánh.
     * @param staff Địa chỉ của nhân viên.
     * @return Metadata chứa (name, phoneNumber, avatar).
     */
    function getStaffMetadata(uint48 branchId, address staff)
        external
        view
        returns (StaffTypes.StaffMetadata memory);
}
