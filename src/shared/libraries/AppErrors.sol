// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @dev Tập hợp toàn bộ Custom Errors của hệ thống để tối ưu Gas và dễ quản lý.
 */

// --- System Core Errors ---
error UnauthorizedAccess();
error InvalidAddress();

// --- Module Manager Errors ---
error ModuleNotRegistered(bytes32 moduleId);
error ModuleAlreadyRegistered(bytes32 moduleId);

// --- Organization Factory Errors ---
error OrgDoesNotExist();
error BranchDoesNotExist();
error ModuleAlreadyEnabled();

// --- Domain/Logic Specific Errors (Dự trù cho sau này) ---
error InvalidPriceConfiguration();
error BalanceInsufficient();

// Các custom error bổ sung cho logic nghiệp vụ
error CodeAlreadyExists();
error ModuleNotEntitled();
error MismatchedBatchInputs();
