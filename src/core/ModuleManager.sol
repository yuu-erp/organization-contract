// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import {ISystemAccessControl} from "./interfaces/ISystemAccessControl.sol";
import {IModuleManager} from "./interfaces/IModuleManager.sol";
import {ModuleManagerStorage} from "./storages/ModuleManagerStorage.sol";
import {ModuleConfig} from "../shared/types/DataTypes.sol";
import {UnauthorizedAccess, InvalidAddress} from "../shared/libraries/AppErrors.sol";

contract ModuleManager is
    Initializable,
    UUPSUpgradeable,
    ModuleManagerStorage
{
    constructor() {
        _disableInitializers();
    }

    function initialize(address _accessControl) public initializer {
        if (_accessControl == address(0)) revert InvalidAddress();
        accessControl = ISystemAccessControl(_accessControl);
    }

    modifier onlyOwner() {
        if (!accessControl.hasRole(bytes32(0), msg.sender))
            revert UnauthorizedAccess();
        _;
    }

    modifier onlyModuleAdminOrOwner(bytes32 parentId) {
        bool isOwner = accessControl.hasRole(bytes32(0), msg.sender);
        bool isAdmin = moduleAdmins[parentId][msg.sender];
        if (!isOwner && !isAdmin) revert UnauthorizedAccess();
        _;
    }

    // --- Core Functions ---

    /**
     * @dev Đăng ký một sub-contract con vào module cha (VD: "IQR" -> "MENU")
     */
    function registerSubModule(
        bytes32 parentId,
        bytes32 subId,
        address beaconAddress
    ) external override onlyOwner {
        if (beaconAddress == address(0)) revert InvalidAddress();

        subModules[parentId][subId] = ModuleConfig({
            beacon: beaconAddress,
            isRegistered: true
        });

        emit SubModuleRegistered(parentId, subId, beaconAddress);
    }

    function grantModuleAdmin(
        bytes32 parentId,
        address opsAdmin
    ) external override onlyOwner {
        if (opsAdmin == address(0)) revert InvalidAddress();
        moduleAdmins[parentId][opsAdmin] = true;
        emit ModuleAdminGranted(parentId, opsAdmin);
    }

    /**
     * @dev Nâng cấp logic cho sub-contract thông qua parentId và subId
     */
    function upgradeSubModuleLogic(
        bytes32 parentId,
        bytes32 subId,
        address newLogicAddress
    ) external override onlyModuleAdminOrOwner(parentId) {
        if (newLogicAddress == address(0)) revert InvalidAddress();

        ModuleConfig memory config = subModules[parentId][subId];
        require(config.isRegistered, "SubModule not registered");

        UpgradeableBeacon(config.beacon).upgradeTo(newLogicAddress);

        emit SubModuleUpgraded(parentId, subId, newLogicAddress);
    }

    function revokeModuleAdmin(
        bytes32 parentId,
        address opsAdmin
    ) external override onlyOwner {
        moduleAdmins[parentId][opsAdmin] = false;
        emit ModuleAdminRevoked(parentId, opsAdmin);
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
