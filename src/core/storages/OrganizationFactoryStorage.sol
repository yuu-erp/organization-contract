// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Organization, Branch} from "../../shared/types/DataTypes.sol";
import {ISystemAccessControl} from "../interfaces/ISystemAccessControl.sol";
import {IModuleManager} from "../interfaces/IModuleManager.sol";
import {IOrganizationFactory} from "../interfaces/IOrganizationFactory.sol";

/**
 * @title OrganizationFactoryStorage
 * @dev Chứa toàn bộ biến trạng thái của Factory.
 */
abstract contract OrganizationFactoryStorage is IOrganizationFactory {
    // --- External Contract References ---
    ISystemAccessControl public accessControl;
    IModuleManager public moduleManager;

    // --- Counters ---
    uint256 public nextOrgId;
    uint256 public nextBranchId;

    // --- Core Mappings ---
    mapping(uint256 => Organization) public organizations;
    mapping(uint256 => Branch) public branches;
    
    // branchId => parentId => subId => address
    mapping(uint256 => mapping(bytes32 => mapping(bytes32 => address))) public branchModules;

    // --- Relational Mappings ---
    // hash(code) => orgId
    mapping(bytes32 => uint256) public codeToOrgId;

    // orgId => parentId => subId => bool
    mapping(uint256 => mapping(bytes32 => mapping(bytes32 => bool))) public orgModuleEntitlements;

    // --- Storage Gap ---
    // Bắt buộc nằm ở cuối cùng của contract
    uint256[50] private __gap;
}
