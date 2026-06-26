// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IBranchModuleManager} from "../../core/interfaces/IBranchModuleManager.sol";

/**
 * @title BranchContextUpgradeable
 * @dev Hợp đồng cơ sở (base contract) cho các contract con trong module,
 *      giúp tái sử dụng thông tin context của Chi nhánh và Tổ chức.
 */
abstract contract BranchContextUpgradeable is Initializable {
    // Tối ưu Gas: Pack 3 biến vào chung 1 Storage Slot (256 bits)
    // - address: 160 bits
    // - uint48 (orgId): 48 bits
    // - uint48 (branchId): 48 bits
    // Tổng cộng: 256 bits (vừa vặn 1 Slot)

    address public branchModuleManager;
    uint48 public orgId;
    uint48 public branchId;

    error ModuleDisabled();

    modifier onlyIfModuleEnabled(bytes32 moduleKey) {
        if (
            !IBranchModuleManager(branchModuleManager).isModuleEnabled(
                branchId,
                moduleKey
            )
        ) {
            revert ModuleDisabled();
        }
        _;
    }

    modifier requiresGlobalPermission(uint256 permissionBit) {
        address hr = IBranchModuleManager(branchModuleManager)
            .getBranchStaffManager(branchId);
        if (
            !IBranchStaffManagerContext(hr).hasGlobalPermission(
                msg.sender,
                permissionBit
            )
        ) {
            revert AccessDenied();
        }
        _;
    }

    // Modifier 2: Yêu cầu quyền Module (Ví dụ: MEOS PC Manager)
    modifier requiresModulePermission(
        bytes32 moduleKey,
        uint256 permissionBit
    ) {
        address hr = IBranchModuleManager(branchModuleManager)
            .getBranchStaffManager(branchId);
        if (
            !IBranchStaffManagerContext(hr).hasModulePermission(
                msg.sender,
                moduleKey,
                permissionBit
            )
        ) {
            revert AccessDenied();
        }
        _;
    }

    function __BranchContext_init(
        uint48 _branchId,
        uint48 _orgId,
        address _branchModuleManager
    ) internal onlyInitializing {
        branchId = _branchId;
        orgId = _orgId;
        branchModuleManager = _branchModuleManager;
    }
}
