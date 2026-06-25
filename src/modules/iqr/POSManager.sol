// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title POSManager
 * @dev Hợp đồng con quản lý đơn hàng/POS của module IQR.
 */
contract POSManager {
    uint256 public totalOrders;

    function createOrder() external {
        totalOrders++;
    }
}
