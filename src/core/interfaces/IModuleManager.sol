// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ModuleConfig} from "../../shared/types/DataTypes.sol";

/**
 * @title IModuleManager
 * @dev Interface quản lý phân cấp Module (Parent -> Sub) cho hệ thống SaaS.
 */
interface IModuleManager {
    // --- Events ---
    event SubModuleRegistered(
        bytes32 indexed parentId,
        bytes32 indexed subId,
        address indexed beacon
    );
    event ModuleAdminGranted(bytes32 indexed parentId, address indexed admin);
    event ModuleAdminRevoked(bytes32 indexed parentId, address indexed admin);
    event SubModuleUpgraded(
        bytes32 indexed parentId,
        bytes32 indexed subId,
        address indexed newLogic
    );

    // --- Getter Functions ---

    // Getter cho cấu trúc Cha-Con: parentId => subId => ModuleConfig
    function subModules(
        bytes32 parentId,
        bytes32 subId
    ) external view returns (address beacon, bool isRegistered);

    // Getter cho phân quyền: parentId => admin => isGranted
    // Đổi tên hoặc giữ nguyên nếu Interface hiểu rõ context
    function moduleAdmins(
        bytes32 parentId,
        address admin
    ) external view returns (bool);

    // --- Core Functions ---

    // Đăng ký một sub-contract (ví dụ: MENU) vào module cha (ví dụ: IQR)
    function registerSubModule(
        bytes32 parentId,
        bytes32 subId,
        address beaconAddress
    ) external;

    // Cấp quyền Admin cho toàn bộ nhánh của module cha
    function grantModuleAdmin(bytes32 parentId, address opsAdmin) external;

    function revokeModuleAdmin(bytes32 parentId, address opsAdmin) external;

    // Nâng cấp logic cho một sub-contract cụ thể
    function upgradeSubModuleLogic(
        bytes32 parentId,
        bytes32 subId,
        address newLogicAddress
    ) external;
}
