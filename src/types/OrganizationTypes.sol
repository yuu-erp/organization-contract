// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title OrganizationTypes
 * @dev Centralized type definitions for Organization domain
 *      Used across OrganizationManager, storage, and related modules
 */
library OrganizationTypes {
    /**
     * @dev Core Organization entity
     */
    struct Organization {
        uint256 id;
        address owner;
        bool active;
        bool exists;
    }
}
