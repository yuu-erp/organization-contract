// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IModuleFactory} from "../../core/interfaces/IModuleFactory.sol";
import {BranchBeaconProxy} from "../../proxies/BranchBeaconProxy.sol";
import {IqrRoot} from "./IqrRoot.sol";

/**
 * @title IqrFactory
 * @dev Factory để deploy module IQR sử dụng BranchBeaconProxy.
 */
contract IqrFactory is IModuleFactory {
    address public beacon;
    address public posManagerBeacon;
    address public branchModuleManager;

    constructor(address _beacon, address _posManagerBeacon, address _branchModuleManager) {
        beacon = _beacon;
        posManagerBeacon = _posManagerBeacon;
        branchModuleManager = _branchModuleManager;
    }

    function deployModule(
        uint256 branchId,
        uint256 orgId,
        address staffManager
    ) external returns (address moduleRoot) {
        require(msg.sender == branchModuleManager, "Only BranchModuleManager");
        bytes memory initData = abi.encodeCall(
            IqrRoot.initialize,
            (branchId, orgId, staffManager, posManagerBeacon, branchModuleManager)
        );
        moduleRoot = address(new BranchBeaconProxy(beacon, initData, branchId, orgId));
    }
}
