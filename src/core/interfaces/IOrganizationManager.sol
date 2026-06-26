// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IOrganizationManager {
    /**
     * @dev Phát ra khi Organization được tạo.
     */
    event OrganizationCreated(uint48 indexed organizationId, address indexed owner);

    /**
     * @dev Phát ra khi Branch được tạo.
     */
    event BranchCreated(uint48 indexed branchId, uint48 indexed organizationId);

    error InvalidAddress();
    error Unauthorized();
    error OrganizationNotFound();
    error OrganizationAlreadyExists();
    error BranchNotFound();

    /**
     * @dev Tạo mới Organization kèm danh sách module cần đăng ký.
     */
    function createOrganization(address owner, bytes32[] calldata moduleKeys) external returns (uint48 organizationId);

    /**
     * @dev Tạo mới Branch cho Organization kèm danh sách module cần kích hoạt.
     */
    function createBranch(uint48 organizationId, bytes32[] calldata moduleKeysToEnable)
        external
        returns (uint48 branchId);

    /**
     * @dev Cập nhật địa chỉ ModuleRegistry và BranchModuleManager.
     */
    function setRegistryAndManager(address _moduleRegistry, address _branchModuleManager) external;

    /**
     * @dev Trả về organizationId của owner.
     */
    function getOrganizationIdByOwner(address owner) external view returns (uint48);

    /**
     * @dev Trả về danh sách branchId thuộc Organization.
     */
    function getOrganizationBranches(uint48 organizationId) external view returns (uint48[] memory);

    /**
     * @dev Kiểm tra Organization tồn tại.
     */
    function organizationExists(uint48 organizationId) external view returns (bool);

    /**
     * @dev Trả về organizationId của branch.
     */
    function getBranchOrgId(uint48 branchId) external view returns (uint48);

    /**
     * @dev Kiểm tra Branch tồn tại.
     */
    function branchExists(uint48 branchId) external view returns (bool);
}
