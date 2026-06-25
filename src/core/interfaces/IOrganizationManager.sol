// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IOrganizationManager {
    /**
     * @dev Phát ra khi Organization được tạo.
     */
    event OrganizationCreated(
        uint256 indexed organizationId,
        address indexed owner
    );

    /**
     * @dev Phát ra khi Branch được tạo.
     */
    event BranchCreated(
        uint256 indexed branchId,
        uint256 indexed organizationId
    );

    error InvalidAddress();
    error Unauthorized();

    error OrganizationNotFound();
    error OrganizationAlreadyExists();

    error BranchNotFound();

    /**
     * @dev Tạo mới Organization kèm danh sách module cần đăng ký.
     */
    function createOrganization(
        address owner,
        bytes32[] calldata moduleKeys
    ) external returns (uint256 organizationId);

    /**
     * @dev Tạo mới Branch cho Organization kèm danh sách module cần kích hoạt.
     */
    function createBranch(
        uint256 organizationId,
        bytes32[] calldata moduleKeysToEnable
    ) external returns (uint256 branchId);

    /**
     * @dev Cập nhật địa chỉ ModuleRegistry và BranchModuleManager.
     */
    function setRegistryAndManager(
        address _moduleRegistry,
        address _branchModuleManager
    ) external;

    /**
     * @dev Trả về organizationId của owner.
     */
    function getOrganizationIdByOwner(
        address owner
    ) external view returns (uint256);

    /**
     * @dev Trả về danh sách branchId thuộc Organization.
     */
    function getOrganizationBranches(
        uint256 organizationId
    ) external view returns (uint256[] memory);

    /**
     * @dev Kiểm tra Organization tồn tại.
     */
    function organizationExists(
        uint256 organizationId
    ) external view returns (bool);

    /**
     * @dev Trả về organizationId của branch.
     */
    function getBranchOrgId(
        uint256 branchId
    ) external view returns (uint256);

    /**
     * @dev Kiểm tra Branch tồn tại.
     */
    function branchExists(uint256 branchId) external view returns (bool);
}
