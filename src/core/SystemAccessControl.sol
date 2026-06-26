// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {ISystemAccessControl} from "./interfaces/ISystemAccessControl.sol";
import {RoleHashes} from "./constants/RoleHashes.sol";

contract SystemAccessControl is Initializable, AccessControlUpgradeable, UUPSUpgradeable, ISystemAccessControl {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Hàm khởi tạo chạy 1 lần duy nhất khi deploy Proxy
     * @param defaultAdmin Địa chỉ ví Owner của hệ thống
     */
    function initialize(address defaultAdmin) external initializer {
        if (defaultAdmin == address(0)) {
            revert InvalidAddress();
        }

        __AccessControl_init();

        // Owner
        _grantRole(RoleHashes.DEFAULT_ADMIN_ROLE, defaultAdmin);

        // Hierarchy
        _setRoleAdmin(RoleHashes.OPS_ADMIN_ROLE, RoleHashes.DEFAULT_ADMIN_ROLE);

        _setRoleAdmin(RoleHashes.PLATFORM_ADMIN_ROLE, RoleHashes.DEFAULT_ADMIN_ROLE);
    }

    function isPlatformAdmin(address account) external view returns (bool) {
        return hasRole(RoleHashes.PLATFORM_ADMIN_ROLE, account);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(RoleHashes.DEFAULT_ADMIN_ROLE) {}
}
