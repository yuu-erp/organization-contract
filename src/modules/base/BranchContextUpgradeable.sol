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
    uint256 public branchId;
    uint256 public orgId;
    address public branchModuleManager;

    error ModuleDisabled();

    modifier onlyIfModuleEnabled(bytes32 moduleKey) {
        if (!IBranchModuleManager(branchModuleManager).isModuleEnabled(branchId, moduleKey)) {
            revert ModuleDisabled();
        }
        _;
    }

    function __BranchContext_init(
        uint256 _branchId,
        uint256 _orgId,
        address _branchModuleManager
    ) internal onlyInitializing {
        branchId = _branchId;
        orgId = _orgId;
        branchModuleManager = _branchModuleManager;
    }
}
