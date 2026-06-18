// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ISystemAccessControl} from "./interfaces/ISystemAccessControl.sol";
import {RoleHashes} from "../shared/constants/RoleHashes.sol";

contract SystemAccessControl is
    Initializable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    ISystemAccessControl
{
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Hàm khởi tạo chạy 1 lần duy nhất khi deploy Proxy
     * @param defaultAdmin Địa chỉ ví nắm quyền Owner (cao nhất)
     */
    function initialize(address defaultAdmin) public initializer {
        __AccessControl_init();

        // Cấp quyền DEFAULT_ADMIN_ROLE (Owner) cho ví chỉ định
        _grantRole(RoleHashes.DEFAULT_ADMIN_ROLE, defaultAdmin);

        // Thiết lập Hierarchy: Admin tối cao có quyền quản lý cả Ops và Company Admin
        _setRoleAdmin(RoleHashes.OPS_ADMIN_ROLE, RoleHashes.DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(RoleHashes.COMPANY_ADMIN_ROLE, RoleHashes.DEFAULT_ADMIN_ROLE);
    }

    /**
     * @dev Giới hạn quyền nâng cấp contract chỉ dành cho Owner
     */
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(RoleHashes.DEFAULT_ADMIN_ROLE) {}
}
