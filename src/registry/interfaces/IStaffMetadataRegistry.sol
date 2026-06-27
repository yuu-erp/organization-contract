// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {StaffTypes} from "../../types/StaffTypes.sol";

interface IStaffMetadataRegistry {
    event StaffMetadataUpdated(
        uint48 indexed branchId, address indexed staff, string name, string phoneNumber, string avatar
    );

    error InvalidAddress();
    error Unauthorized();
    error BranchNotProvisioned();

    /**
     * @dev Khởi tạo Registry với SystemAccessControl, OrganizationManager và BranchModuleManager.
     */
    function initialize(
        address accessControlAddress,
        address organizationManagerAddress,
        address branchModuleManagerAddress
    ) external;

    /**
     * @dev Cập nhật metadata cho nhân viên tại chi nhánh cụ thể.
     */
    function setStaffMetadata(
        uint48 branchId,
        address staff,
        string calldata name,
        string calldata phoneNumber,
        string calldata avatar
    ) external;

    /**
     * @dev Đọc metadata của nhân viên tại chi nhánh.
     */
    function getStaffMetadata(uint48 branchId, address staff) external view returns (StaffTypes.StaffMetadata memory);
}
