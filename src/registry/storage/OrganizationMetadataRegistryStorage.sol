// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ISystemAccessControl} from "../../core/interfaces/ISystemAccessControl.sol";
import {IOrganizationManager} from "../../core/interfaces/IOrganizationManager.sol";
import {OrganizationTypes} from "../../types/OrganizationTypes.sol";
import {BranchTypes} from "../../types/BranchTypes.sol";

/**
 * @title OrganizationMetadataRegistryStorage
 * @dev Storage layout for OrganizationMetadataRegistry, supports safe UUPS upgrades.
 */
abstract contract OrganizationMetadataRegistryStorage {
    // --- Slot 1 ---
    ISystemAccessControl public accessControl;

    // --- Slot 2 ---
    IOrganizationManager public organizationManager;

    // --- Dynamic Storage ---
    mapping(uint48 => OrganizationTypes.OrganizationMetadata) internal _orgMetadata;
    mapping(uint48 => BranchTypes.BranchMetadata) internal _branchMetadata;

    /**
     * @dev Reserved storage space to allow for layout upgrades without collisions.
     */
    uint256[48] private __gap;
}
