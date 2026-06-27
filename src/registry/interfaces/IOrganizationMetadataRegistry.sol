// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {OrganizationTypes} from "../../types/OrganizationTypes.sol";
import {BranchTypes} from "../../types/BranchTypes.sol";

interface IOrganizationMetadataRegistry {
    event OrganizationMetadataUpdated(
        uint48 indexed organizationId,
        string name,
        string organizationAddress,
        string phoneNumber
    );

    event BranchMetadataUpdated(
        uint48 indexed branchId,
        string name,
        string organizationAddress,
        string phoneNumber,
        string code
    );

    error InvalidAddress();
    error Unauthorized();
    error OrganizationNotFound();
    error BranchNotFound();

    /**
     * @dev Khởi tạo Registry với SystemAccessControl.
     */
    function initialize(address accessControlAddress, address organizationManagerAddress) external;

    /**
     * @dev Cập nhật metadata cho Organization.
     */
    function setOrganizationMetadata(
        uint48 organizationId,
        string calldata name,
        string calldata organizationAddress,
        string calldata phoneNumber
    ) external;

    /**
     * @dev Cập nhật metadata cho Branch.
     */
    function setBranchMetadata(
        uint48 branchId,
        string calldata name,
        string calldata organizationAddress,
        string calldata phoneNumber,
        string calldata code
    ) external;

    /**
     * @dev Đọc metadata của Organization.
     */
    function getOrganizationMetadata(uint48 organizationId)
        external
        view
        returns (OrganizationTypes.OrganizationMetadata memory);

    /**
     * @dev Đọc metadata của Branch.
     */
    function getBranchMetadata(uint48 branchId) external view returns (BranchTypes.BranchMetadata memory);
}
