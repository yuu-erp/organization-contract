// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {POSManager} from "./POSManager.sol";

/**
 * @title IqrRoot
 * @dev Hợp đồng chính (root) cho module IQR.
 */
contract IqrRoot is Initializable {
    uint256 public branchId;
    uint256 public orgId;
    address public staffManager;
    address public posManager;

    function initialize(
        uint256 _branchId,
        uint256 _orgId,
        address _staffManager
    ) external initializer {
        branchId = _branchId;
        orgId = _orgId;
        staffManager = _staffManager;
        posManager = address(new POSManager());
    }
}
