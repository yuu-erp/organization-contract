// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library ModuleConstants {
    // Parent Modules
    bytes32 public constant MEOS = keccak256("MEOS");
    bytes32 public constant IQR = keccak256("IQR");
    bytes32 public constant LOYALTY = keccak256("LOYALTY");

    // Sub-Modules của MEOS
    bytes32 public constant MEOS_CORE = keccak256("MEOS_CORE");

    // Sub-Modules của IQR
    bytes32 public constant IQR_CORE = keccak256("IQR_CORE");
    bytes32 public constant IQR_MENU = keccak256("IQR_MENU");
    bytes32 public constant IQR_ORDER = keccak256("IQR_ORDER");
}
