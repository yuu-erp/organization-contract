// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title OrganizationTypes
 * @dev Centralized type definitions for Organization domain
 */
library OrganizationTypes {
    /**
     * @dev Core Organization entity (Packed to 1 Storage Slot)
     */
    struct Organization {
        address owner; // 160 bits
        uint48 id; // 48 bits
        bool active; // 8 bits
        bool exists; // 8 bits
        // Total: 224 bits
    }

    struct OrganizationMetadata {
        string name;
        string organizationAddress;
        string phoneNumber;
    }
}
