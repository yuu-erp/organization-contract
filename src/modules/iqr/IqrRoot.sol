// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {POSManager} from "./POSManager.sol";

/**
 * @title IqrRoot
 * @dev Hợp đồng chính (root) cho module IQR.
 */
contract IqrRoot is Initializable {
    uint48 public branchId;
    uint48 public orgId;
    address public staffManager;
    address public posManager;
    address public branchModuleManager;

    function initialize(
        uint48 _branchId,
        uint48 _orgId,
        address _staffManager,
        address _posManagerBeacon,
        address _branchModuleManager
    ) external initializer {
        branchId = _branchId;
        orgId = _orgId;
        staffManager = _staffManager;
        branchModuleManager = _branchModuleManager;

        posManager = address(
            new BeaconProxy(
                _posManagerBeacon,
                abi.encodeCall(
                    POSManager.initialize,
                    (_branchId, _orgId, _branchModuleManager)
                )
            )
        );
    }

    function getSubContracts() external view returns (address _posManager) {
        return posManager;
    }
}
