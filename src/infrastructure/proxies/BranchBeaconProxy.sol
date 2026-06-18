// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";

/**
 * @title BranchBeaconProxy
 * @dev Custom Proxy tối ưu Gas. Nhúng trực tiếp định danh của Chi nhánh và Tổ chức vào Bytecode.
 */
contract BranchBeaconProxy is BeaconProxy {
    // Biến immutable không chiếm slot trong Storage.
    // Chúng được lưu trực tiếp vào mã bytecode của hợp đồng.
    uint256 public immutable BRANCH_ID;
    uint256 public immutable ORG_ID;

    /**
     * @dev Khởi tạo Proxy, trỏ về ngọn hải đăng và thực thi data khởi tạo của Logic
     */
    constructor(
        address beacon,
        bytes memory data,
        uint256 _branchId,
        uint256 _orgId
    ) BeaconProxy(beacon, data) {
        BRANCH_ID = _branchId;
        ORG_ID = _orgId;
    }

    receive() external payable {}
}
