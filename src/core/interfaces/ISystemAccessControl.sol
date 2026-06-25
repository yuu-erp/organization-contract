// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

/**
 * @title ISystemAccessControl
 * @dev Interface chuẩn hóa cho hợp đồng quản lý phân quyền của hệ thống.
 */
interface ISystemAccessControl is IAccessControl {
    error InvalidAddress();

    function isPlatformAdmin(address account) external view returns (bool);
}
