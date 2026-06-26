// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";

/**
 * @title BranchBeaconProxy
 * @dev Custom Proxy tối ưu Gas. Nhúng trực tiếp định danh của Chi nhánh và Tổ chức vào Bytecode.
 * Đã đồng bộ kiểu dữ liệu uint48 cho toàn hệ thống.
 */
contract BranchBeaconProxy is BeaconProxy {
    // Biến immutable không chiếm slot trong Storage.
    // Chúng được lưu trực tiếp vào mã bytecode của hợp đồng.
    uint48 public immutable BRANCH_ID;
    uint48 public immutable ORG_ID;

    /**
     * @dev Khởi tạo Proxy, trỏ về ngọn hải đăng và thực thi data khởi tạo của Logic
     */
    constructor(address beacon, bytes memory data, uint48 _branchId, uint48 _orgId) BeaconProxy(beacon, data) {
        BRANCH_ID = _branchId;
        ORG_ID = _orgId;
    }
}
