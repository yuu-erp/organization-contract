// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
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
    address public branchModuleManager;

    function initialize(
        uint256 _branchId,
        uint256 _orgId,
        address _staffManager,
        address _pointManagerBeacon,
        address _branchModuleManager
    ) external initializer {
        branchId = _branchId;
        orgId = _orgId;
        staffManager = _staffManager;
        branchModuleManager = _branchModuleManager;

        pointManager = address(new BeaconProxy(
            _pointManagerBeacon,
            abi.encodeCall(PointManager.initialize, (_branchId, _orgId, _branchModuleManager))
        ));
    }

    function getSubContracts() external view returns (address _pointManager) {
        return pointManager;
    }
}
