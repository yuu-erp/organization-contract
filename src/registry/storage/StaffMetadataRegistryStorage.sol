// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ISystemAccessControl} from "../../core/interfaces/ISystemAccessControl.sol";
import {IOrganizationManager} from "../../core/interfaces/IOrganizationManager.sol";
import {IBranchModuleManager} from "../../core/interfaces/IBranchModuleManager.sol";
import {StaffTypes} from "../../types/StaffTypes.sol";

/**
 * @title StaffMetadataRegistryStorage
 * @dev Định nghĩa bố cục bộ nhớ (Storage Layout) của StaffMetadataRegistry, đảm bảo nâng cấp UUPS an toàn.
 */
abstract contract StaffMetadataRegistryStorage {
    // --- Slot 1 ---
    ISystemAccessControl public accessControl;

    // --- Slot 2 ---
    IOrganizationManager public organizationManager;

    // --- Slot 3 ---
    IBranchModuleManager public branchModuleManager;

    // --- Dynamic Storage ---
    // branchId => staffAddress => StaffMetadata
    mapping(uint48 => mapping(address => StaffTypes.StaffMetadata)) internal _staffMetadata;

    /**
     * @dev Khoảng trống dự phòng để cho phép thêm các biến storage trong tương lai mà không bị xung đột bộ nhớ.
     */
    uint256[47] private __gap;
}
