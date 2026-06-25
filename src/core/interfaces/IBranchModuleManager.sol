// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IBranchModuleManager
 * @dev Interface cho BranchModuleManager — orchestrator deploy và quản lý module cho branch.
 */
interface IBranchModuleManager {
    // ====== Events ======

    event BranchProvisioned(
        uint256 indexed branchId,
        uint256 indexed orgId,
        address staffManager
    );

    event ModuleEnabled(
        uint256 indexed branchId,
        bytes32 indexed moduleKey,
        address moduleRoot
    );

    event ModuleDisabled(uint256 indexed branchId, bytes32 indexed moduleKey);

    // ====== Errors ======

    error InvalidAddress();
    error Unauthorized();
    error BranchAlreadyProvisioned();
    error BranchNotProvisioned();
    error ModuleAlreadyEnabled();
    error ModuleNotEnabled();
    error OrgNotSubscribedToModule();
    error InvalidInput();

    // ====== Core Functions ======

    /**
     * @dev Provision branch: deploy shared StaffManager.
     *      Phải gọi trước khi enable module.
     */
    function provisionBranch(uint256 branchId, uint256 orgId) external;

    /**
     * @dev Enable module cho branch đã provision.
     *      Gọi factory deploy module bundle.
     */
    function enableModule(
        uint256 branchId,
        bytes32 moduleKey
    ) external returns (address moduleRoot);

    /**
     * @dev Disable module (soft — giữ data, chỉ disable).
     */
    function disableModule(uint256 branchId, bytes32 moduleKey) external;

    // ====== View Functions ======

    /**
     * @dev Kiểm tra branch đã được provision chưa.
     */
    function isBranchProvisioned(
        uint256 branchId
    ) external view returns (bool);

    /**
     * @dev Lấy StaffManager address của branch.
     */
    function getBranchStaffManager(
        uint256 branchId
    ) external view returns (address);

    /**
     * @dev Lấy module root address.
     */
    function getModuleRoot(
        uint256 branchId,
        bytes32 moduleKey
    ) external view returns (address);

    /**
     * @dev Lấy danh sách module keys + addresses của branch.
     */
    function getBranchModules(
        uint256 branchId
    ) external view returns (bytes32[] memory keys, address[] memory roots);

    /**
     * @dev Kiểm tra module có đang enabled cho branch không.
     */
    function isModuleEnabled(
        uint256 branchId,
        bytes32 moduleKey
    ) external view returns (bool);
}
