// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {OrganizationTypes} from "../../types/OrganizationTypes.sol";
import {BranchTypes} from "../../types/BranchTypes.sol";

interface IOrganizationReader {
    struct FullOrganizationInfo {
        uint48 id;
        address owner;
        bool active;
        bool exists;
        string name;
        string organizationAddress;
        string phoneNumber;
    }

    struct FullBranchInfo {
        uint48 id;
        address owner;
        uint48 organizationId;
        bool active;
        bool exists;
        string name;
        string organizationAddress;
        string phoneNumber;
        string code;
    }

    error InvalidAddress();
    error OrganizationNotFound();
    error BranchNotFound();

    /**
     * @dev Lấy đầy đủ thông tin của Organization bao gồm cả core và metadata.
     */
    function getFullOrganizationInfo(
        uint48 organizationId
    ) external view returns (FullOrganizationInfo memory);

    /**
     * @dev Lấy đầy đủ thông tin của Branch bao gồm cả core và metadata.
     */
    function getFullBranchInfo(
        uint48 branchId
    ) external view returns (FullBranchInfo memory);

    /**
     * @dev Lấy danh sách đầy đủ thông tin tất cả các Branch của một Organization.
     */
    function getOrganizationBranchesFull(
        uint48 organizationId
    ) external view returns (FullBranchInfo[] memory);

    /**
     * @dev Lấy danh sách thông tin các Branch có phân trang.
     */
    function getOrganizationBranchesPaginated(
        uint48 organizationId,
        uint256 offset,
        uint256 limit
    ) external view returns (FullBranchInfo[] memory);
}
