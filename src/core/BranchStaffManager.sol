// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title BranchStaffManager
 * @dev Hợp đồng con quản lý nhân sự tại chi nhánh (shared service).
 */
contract BranchStaffManager is Initializable {
    uint256 public branchId;
    address public accessControl;

    function initialize(uint256 _branchId, address _accessControl) external initializer {
        branchId = _branchId;
        accessControl = _accessControl;
    }
}
