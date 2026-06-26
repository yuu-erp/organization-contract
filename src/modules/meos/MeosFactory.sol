// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IModuleFactory} from "../../core/interfaces/IModuleFactory.sol";
import {BranchBeaconProxy} from "../../proxies/BranchBeaconProxy.sol";
import {MeosRoot} from "./MeosRoot.sol";

/**
 * @title MeosFactory
 * @dev Factory để deploy module MEOS sử dụng BranchBeaconProxy.
 * Đã đồng bộ kiểu dữ liệu uint48 cho định danh Branch và Org.
 */
contract MeosFactory is IModuleFactory {
    address public beacon;
    address public pcManagerBeacon;
    address public accountManagerBeacon;
    address public branchModuleManager;

    constructor(
        address _beacon,
        address _pcManagerBeacon,
        address _accountManagerBeacon,
        address _branchModuleManager
    ) {
        beacon = _beacon;
        pcManagerBeacon = _pcManagerBeacon;
        accountManagerBeacon = _accountManagerBeacon;
        branchModuleManager = _branchModuleManager;
    }

    modifier onlyBranchModuleManager() {
        require(msg.sender == branchModuleManager, "Only BranchModuleManager");
        _;
    }

    function deployModule(
        uint48 branchId,
        uint48 orgId,
        address staffManager
    ) external onlyBranchModuleManager returns (address moduleRoot) {
        // LƯU Ý: Để hàm abi.encodeCall này không báo lỗi,
        // hàm initialize trong contract MeosRoot.sol cũng BẮT BUỘC phải đổi sang uint48.
        bytes memory initData = abi.encodeCall(
            MeosRoot.initialize,
            (
                branchId,
                orgId,
                staffManager,
                pcManagerBeacon,
                accountManagerBeacon,
                msg.sender
            )
        );

        moduleRoot = address(
            new BranchBeaconProxy(beacon, initData, branchId, orgId)
        );
    }
}
