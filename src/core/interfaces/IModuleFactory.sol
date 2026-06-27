// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IModuleFactory
 * @dev Interface chuẩn cho tất cả Module Factory.
 *      Mỗi module type (MEOS, IQR, Loyalty,...) có 1 factory implement interface này.
 *      Factory biết cách deploy toàn bộ bundle (root + sub-contracts).
 */
interface IModuleFactory {
    /**
     * @dev Deploy toàn bộ module bundle cho 1 branch.
     * @param branchId ID của chi nhánh
     * @param orgId ID của tổ chức
     * @param staffManager Địa chỉ BranchStaffManager (shared) — có thể = address(0) nếu chưa deploy
     * @return moduleRoot Địa chỉ root contract của module bundle
     */
    function deployModule(uint48 branchId, uint48 orgId, address staffManager) external returns (address moduleRoot);
}
