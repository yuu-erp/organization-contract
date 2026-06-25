// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {ISystemAccessControl} from "../interfaces/ISystemAccessControl.sol";
import {IOrganizationManager} from "../interfaces/IOrganizationManager.sol";
import {IModuleRegistry} from "../interfaces/IModuleRegistry.sol";

/**
 * @title BranchModuleManagerStorage
 * @dev Lưu trữ toàn bộ state của BranchModuleManager.
 *      Tách riêng để đảm bảo ổn định storage layout khi upgrade.
 */
abstract contract BranchModuleManagerStorage {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    /**
     * @dev Contract quản lý phân quyền hệ thống.
     */
    ISystemAccessControl public accessControl;

    /**
     * @dev Contract quản lý Organization và Branch.
     */
    IOrganizationManager public organizationManager;

    /**
     * @dev Contract đăng ký module.
     */
    IModuleRegistry public moduleRegistry;

    /**
     * @dev Beacon address cho BranchStaffManager.
     */
    address public staffManagerBeacon;

    /**
     * @dev BranchStaffManager address per branch.
     * branchId => staffManager address
     */
    mapping(uint256 => address) public branchStaffManagers;

    /**
     * @dev Module root address per branch per module.
     * branchId => moduleKey => moduleRoot address
     */
    mapping(uint256 => mapping(bytes32 => address)) public branchModuleRoots;

    /**
     * @dev Danh sách module đang enabled per branch.
     * branchId => set of moduleKeys
     */
    mapping(uint256 => EnumerableSet.Bytes32Set) internal branchEnabledModules;

    /**
     * @dev Branch đã được provision chưa.
     * branchId => bool
     */
    mapping(uint256 => bool) public branchProvisioned;
}
