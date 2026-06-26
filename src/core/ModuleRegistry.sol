// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {RoleHashes} from "./constants/RoleHashes.sol";

import {ISystemAccessControl} from "./interfaces/ISystemAccessControl.sol";
import {IModuleRegistry} from "./interfaces/IModuleRegistry.sol";

import {ModuleTypes} from "../types/ModuleTypes.sol";

import {ModuleRegistryStorage} from "./storage/ModuleRegistryStorage.sol";

/**
 * @title ModuleRegistry
 * @dev Trung tâm đăng ký module và quản lý subscription cho Organization.
 *
 * - OPS_ADMIN đăng ký module mới (registerModule)
 * - PLATFORM_ADMIN kích hoạt module cho org (subscribeOrgToModule)
 * - BranchModuleManager query factory address để deploy
 */
contract ModuleRegistry is
    Initializable,
    UUPSUpgradeable,
    ModuleRegistryStorage,
    IModuleRegistry
{
    using EnumerableSet for EnumerableSet.Bytes32Set;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Khởi tạo contract.
     * @param accessControlAddress Địa chỉ SystemAccessControl.
     */
    function initialize(address accessControlAddress) external initializer {
        if (accessControlAddress == address(0)) {
            revert InvalidAddress();
        }

        accessControl = ISystemAccessControl(accessControlAddress);
    }

    // ====== Modifiers ======

    modifier onlyOpsAdmin() {
        if (!accessControl.hasRole(RoleHashes.OPS_ADMIN_ROLE, msg.sender)) {
            revert Unauthorized();
        }
        _;
    }

    modifier onlyPlatformAdmin() {
        if (
            !accessControl.hasRole(RoleHashes.PLATFORM_ADMIN_ROLE, msg.sender)
        ) {
            revert Unauthorized();
        }
        _;
    }

    // ====== Admin Functions ======

    /**
     * @dev Đăng ký module mới vào hệ thống.
     * Chỉ OPS_ADMIN mới được gọi.
     */
    function registerModule(
        bytes32 key,
        string calldata name,
        address factory
    ) external onlyOpsAdmin {
        if (factory == address(0)) {
            revert InvalidAddress();
        }

        if (moduleDefinitions[key].exists) {
            revert ModuleAlreadyRegistered();
        }

        moduleDefinitions[key] = ModuleTypes.ModuleDefinition({
            key: key,
            name: name,
            factory: factory,
            active: true,
            exists: true
        });

        registeredModuleKeys.add(key);

        emit ModuleRegistered(key, name, factory);
    }

    /**
     * @dev Cập nhật factory address của module.
     */
    function updateModuleFactory(
        bytes32 key,
        address newFactory
    ) external onlyOpsAdmin {
        if (newFactory == address(0)) {
            revert InvalidAddress();
        }

        _requireModuleExists(key);

        moduleDefinitions[key].factory = newFactory;

        emit ModuleUpdated(key, newFactory);
    }

    /**
     * @dev Bật/tắt module trên toàn hệ thống.
     */
    function setModuleActive(bytes32 key, bool active) external onlyOpsAdmin {
        _requireModuleExists(key);

        moduleDefinitions[key].active = active;

        emit ModuleStatusChanged(key, active);
    }

    // ====== Subscription Functions ======

    /**
     * @dev Kích hoạt module cho Organization.
     */
    function subscribeOrgToModule(
        uint48 orgId,
        bytes32 moduleKey
    ) external onlyPlatformAdmin {
        _requireModuleExists(moduleKey);

        if (!moduleDefinitions[moduleKey].active) {
            revert ModuleNotActive();
        }

        if (orgSubscribedModules[orgId].contains(moduleKey)) {
            revert OrgAlreadySubscribed();
        }

        orgSubscribedModules[orgId].add(moduleKey);

        emit OrgModuleSubscribed(orgId, moduleKey);
    }

    /**
     * @dev Huỷ đăng ký module cho Organization.
     */
    function unsubscribeOrgFromModule(
        uint48 orgId,
        bytes32 moduleKey
    ) external onlyPlatformAdmin {
        if (!orgSubscribedModules[orgId].contains(moduleKey)) {
            revert OrgNotSubscribed();
        }

        orgSubscribedModules[orgId].remove(moduleKey);

        emit OrgModuleUnsubscribed(orgId, moduleKey);
    }

    // ====== View Functions ======

    /**
     * @dev Kiểm tra org đã subscribe module chưa.
     */
    function isOrgSubscribed(
        uint48 orgId,
        bytes32 moduleKey
    ) external view returns (bool) {
        return orgSubscribedModules[orgId].contains(moduleKey);
    }

    /**
     * @dev Lấy danh sách module keys mà org đã subscribe.
     */
    function getOrgModules(
        uint48 orgId
    ) external view returns (bytes32[] memory keys) {
        EnumerableSet.Bytes32Set storage modules = orgSubscribedModules[orgId];
        uint256 length = modules.length();

        keys = new bytes32[](length);

        for (uint256 i; i < length; i++) {
            keys[i] = modules.at(i);
        }
    }

    /**
     * @dev Lấy factory address của module.
     */
    function getModuleFactory(bytes32 key) external view returns (address) {
        _requireModuleExists(key);
        return moduleDefinitions[key].factory;
    }

    /**
     * @dev Kiểm tra module tồn tại và active.
     */
    function isModuleActive(bytes32 key) external view returns (bool) {
        return moduleDefinitions[key].exists && moduleDefinitions[key].active;
    }

    /**
     * @dev Lấy danh sách tất cả module keys đã đăng ký.
     */
    function getAllModuleKeys() external view returns (bytes32[] memory keys) {
        uint256 length = registeredModuleKeys.length();

        keys = new bytes32[](length);

        for (uint256 i; i < length; i++) {
            keys[i] = registeredModuleKeys.at(i);
        }
    }

    // ====== Internal ======

    function _requireModuleExists(bytes32 key) internal view {
        if (!moduleDefinitions[key].exists) {
            revert ModuleNotFound();
        }
    }

    /**
     * @dev Chỉ DEFAULT_ADMIN mới được nâng cấp.
     */
    function _authorizeUpgrade(address newImplementation) internal override {
        if (!accessControl.hasRole(RoleHashes.DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert Unauthorized();
        }
    }
}
