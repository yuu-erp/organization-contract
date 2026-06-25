// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title BranchTypes
 * @dev Centralized type definitions for Branch domain
 *      Used across BranchManager, OrganizationManager, and storage layer
 */
library BranchTypes {
    /**
     * @dev Core Branch entity
     */
    struct Branch {
        uint256 organizationId; // Parent organization
        address owner; // Branch admin/owner
        bool active; // Status flag
        bool exists; // Initialization flag
    }
}
