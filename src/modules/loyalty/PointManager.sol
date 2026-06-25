// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title PointManager
 * @dev Hợp đồng con quản lý điểm thưởng của module Loyalty.
 */
contract PointManager {
    mapping(address => uint256) public userPoints;

    function addPoints(address user, uint256 amount) external {
        userPoints[user] += amount;
    }
}
