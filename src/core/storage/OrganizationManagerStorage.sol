// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {ISystemAccessControl} from "../interfaces/ISystemAccessControl.sol";
import {OrganizationTypes} from "../../types/OrganizationTypes.sol";
import {BranchTypes} from "../../types/BranchTypes.sol";

/**
 * @title OrganizationManagerStorage
 * @dev Contract chỉ chứa storage layout và được kế thừa bởi OrganizationManager.
 */
abstract contract OrganizationManagerStorage {
    using EnumerableSet for EnumerableSet.UintSet;

    // --- Slot 1 ---
    ISystemAccessControl public accessControl; // 160 bits

    // --- Slot 2 (Packed: 160 + 48 + 48 = 256 bits) ---
    address public moduleRegistry; // 160 bits
    uint48 public organizationCounter; // 48 bits
    uint48 public branchCounter; // 48 bits

    // --- Slot 3 ---
    address public branchModuleManager; // 160 bits

    // --- Dynamic Storage ---
    mapping(uint48 => OrganizationTypes.Organization) public organizations;
    mapping(address => uint48) public ownerToOrganizationId;
    mapping(uint48 => BranchTypes.Branch) public branches;

    // Note: OpenZeppelin UintSet uses uint256 internally.
    // You will need to cast uint48 to uint256 when adding to this set in the implementation.
    mapping(uint48 => EnumerableSet.UintSet) internal organizationBranches;
}
