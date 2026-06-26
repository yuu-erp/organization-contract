// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title BranchTypes
 * @dev Centralized type definitions for Branch domain
 */
library BranchTypes {
    /**
     * @dev Core Branch entity (Packed to 1 Storage Slot)
     */
    struct Branch {
        address owner; // 160 bits
        uint48 organizationId; // 48 bits
        bool active; // 8 bits
        bool exists; // 8 bits
        // Total: 224 bits
    }
}
