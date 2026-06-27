// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {ISystemAccessControl} from "../../core/interfaces/ISystemAccessControl.sol";

import {ModuleTypes} from "../../types/ModuleTypes.sol";

/**
 * @title ModuleRegistryStorage
 * @dev Lưu trữ toàn bộ state của ModuleRegistry.
 *      Tách riêng để đảm bảo ổn định storage layout khi upgrade.
 */
abstract contract ModuleRegistryStorage {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    /**
     * @dev Contract quản lý phân quyền hệ thống.
     */
    ISystemAccessControl public accessControl;

    /**
     * @dev Lưu trữ định nghĩa module theo key.
     */
    mapping(bytes32 => ModuleTypes.ModuleDefinition) public moduleDefinitions;

    /**
     * @dev Danh sách tất cả module keys đã đăng ký.
     */
    EnumerableSet.Bytes32Set internal registeredModuleKeys;

    /**
     * @dev Danh sách module mà Organization đã subscribe.
     * orgId => set of moduleKeys
     */
    mapping(uint256 => EnumerableSet.Bytes32Set) internal orgSubscribedModules;
}
