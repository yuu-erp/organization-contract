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
     * @dev Tạo mới Organization.
     *
     * Yêu cầu:
     * - owner != address(0)
     * - owner chưa sở hữu Organization nào
     */
    function createOrganization(
        address owner
    ) external returns (uint256 organizationId);

    /**
     * @dev Tạo mới Branch cho Organization.
     *
     * Yêu cầu:
     * - organizationId tồn tại
     */
    function createBranch(
        uint256 organizationId
    ) external returns (uint256 branchId);

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
     * @dev Kiểm tra Branch tồn tại.
     */
    function branchExists(uint256 branchId) external view returns (bool);
}
