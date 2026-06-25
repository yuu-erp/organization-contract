// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {PointManager} from "./PointManager.sol";

/**
 * @title LoyaltyRoot
 * @dev Hợp đồng chính (root) cho module Loyalty.
 */
contract LoyaltyRoot is Initializable {
    uint256 public branchId;
    uint256 public orgId;
    address public staffManager;
    address public pointManager;

    function initialize(
        uint256 _branchId,
        uint256 _orgId,
        address _staffManager
    ) external initializer {
        branchId = _branchId;
        orgId = _orgId;
        staffManager = _staffManager;
        pointManager = address(new PointManager());
    }
}
