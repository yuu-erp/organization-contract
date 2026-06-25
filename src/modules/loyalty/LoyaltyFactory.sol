// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IModuleFactory} from "../../core/interfaces/IModuleFactory.sol";
import {BranchBeaconProxy} from "../../proxies/BranchBeaconProxy.sol";

/**
 * @title LoyaltyFactory
 * @dev Factory để deploy module Loyalty sử dụng BranchBeaconProxy.
 */
contract LoyaltyFactory is IModuleFactory {
    address public beacon;

    constructor(address _beacon) {
        beacon = _beacon;
    }

    function deployModule(
        uint256 branchId,
        uint256 orgId,
        address staffManager
    ) external returns (address moduleRoot) {
        bytes memory initData = abi.encodeWithSignature(
            "initialize(uint256,uint256,address)",
            branchId,
            orgId,
            staffManager
        );
        moduleRoot = address(new BranchBeaconProxy(beacon, initData, branchId, orgId));
    }
}
