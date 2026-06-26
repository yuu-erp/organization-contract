// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IModuleFactory} from "../../core/interfaces/IModuleFactory.sol";
import {BranchBeaconProxy} from "../../proxies/BranchBeaconProxy.sol";
import {LoyaltyRoot} from "./LoyaltyRoot.sol";

/**
 * @title LoyaltyFactory
 * @dev Factory để deploy module Loyalty sử dụng BranchBeaconProxy.
 */
contract LoyaltyFactory is IModuleFactory {
    address public beacon;
    address public pointManagerBeacon;
    address public branchModuleManager;

    constructor(address _beacon, address _pointManagerBeacon, address _branchModuleManager) {
        beacon = _beacon;
        pointManagerBeacon = _pointManagerBeacon;
        branchModuleManager = _branchModuleManager;
    }

    function deployModule(
        uint256 branchId,
        uint256 orgId,
        address staffManager
    ) external returns (address moduleRoot) {
        require(msg.sender == branchModuleManager, "Only BranchModuleManager");
        bytes memory initData = abi.encodeCall(
            LoyaltyRoot.initialize,
            (branchId, orgId, staffManager, pointManagerBeacon, branchModuleManager)
        );
        moduleRoot = address(new BranchBeaconProxy(beacon, initData, branchId, orgId));
    }
}
