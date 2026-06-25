// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {ISystemAccessControl} from "../interfaces/ISystemAccessControl.sol";

import {OrganizationTypes} from "../../types/OrganizationTypes.sol";
import {BranchTypes} from "../../types/BranchTypes.sol";

/**
 * @title OrganizationManagerStorage
 * @dev Lưu trữ toàn bộ state của Organization và Branch.
 *
 * Contract này chỉ chứa storage layout và được kế thừa bởi
 * OrganizationManager nhằm đảm bảo tính ổn định khi nâng cấp.
 */
abstract contract OrganizationManagerStorage {
    using EnumerableSet for EnumerableSet.UintSet;

    /**
     * @dev Contract quản lý phân quyền hệ thống.
     */
    ISystemAccessControl public accessControl;

    /**
     * @dev Bộ đếm định danh Organization.
     */
    uint256 public organizationCounter;

    /**
     * @dev Lưu trữ thông tin Organization theo organizationId.
     */
    mapping(uint256 => OrganizationTypes.Organization) public organizations;

    /**
     * @dev Tra cứu Organization theo owner.
     * owner => organizationId
     */
    mapping(address => uint256) public ownerToOrganizationId;

    /**
     * @dev Bộ đếm định danh Branch.
     */
    uint256 public branchCounter;

    /**
     * @dev Lưu trữ thông tin Branch theo branchId.
     */
    mapping(uint256 => BranchTypes.Branch) public branches;

    /**
     * @dev Danh sách Branch thuộc về một Organization.
     * organizationId => branchIds
     */
    mapping(uint256 => EnumerableSet.UintSet) internal organizationBranches;
}
