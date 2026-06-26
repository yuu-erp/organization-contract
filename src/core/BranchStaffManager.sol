// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title BranchStaffManager
 * @dev Hợp đồng con quản lý nhân sự tại chi nhánh (shared service).
 */
contract BranchStaffManager is Initializable {
    // --- Tối ưu Storage Packing (208/256 bits) ---
    address public accessControl; // 160 bits
    uint48 public branchId; // 48 bits

    /**
     * @dev Khởi tạo contract thông qua BeaconProxy
     * Lưu ý: Signature phải khớp chính xác với abi.encodeWithSignature("initialize(uint48,address)", ...)
     */
    function initialize(
        uint48 _branchId,
        address _accessControl
    ) external initializer {
        branchId = _branchId;
        accessControl = _accessControl;
    }
}
