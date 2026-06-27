// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IOrganizationReader} from "./interfaces/IOrganizationReader.sol";
import {IOrganizationMetadataRegistry} from "../registry/interfaces/IOrganizationMetadataRegistry.sol";
import {OrganizationTypes} from "../types/OrganizationTypes.sol";
import {BranchTypes} from "../types/BranchTypes.sol";

interface IOrganizationManagerGetter {
    function organizations(uint48 orgId)
        external
        view
        returns (
            address owner,
            uint48 id,
            bool active,
            bool exists
        );

    function branches(uint48 branchId)
        external
        view
        returns (
            address owner,
            uint48 organizationId,
            bool active,
            bool exists
        );

    function getOrganizationBranches(uint48 organizationId) external view returns (uint48[] memory);
}

/**
 * @title OrganizationReader
 * @dev View Contract gộp dữ liệu truy vấn từ OrganizationManager và OrganizationMetadataRegistry cho Frontend.
 */
contract OrganizationReader is IOrganizationReader, Ownable {
    IOrganizationManagerGetter public organizationManager;
    IOrganizationMetadataRegistry public metadataRegistry;

    event ContractsUpdated(address indexed organizationManager, address indexed metadataRegistry);

    constructor(
        address _organizationManager,
        address _metadataRegistry,
        address _initialOwner
    ) Ownable(_initialOwner) {
        if (_organizationManager == address(0) || _metadataRegistry == address(0)) {
            revert InvalidAddress();
        }
        organizationManager = IOrganizationManagerGetter(_organizationManager);
        metadataRegistry = IOrganizationMetadataRegistry(_metadataRegistry);
    }

    /**
     * @dev Cập nhật địa chỉ của OrganizationManager và OrganizationMetadataRegistry.
     * @param _organizationManager Địa chỉ Manager mới.
     * @param _metadataRegistry Địa chỉ Registry mới.
     */
    function updateContracts(address _organizationManager, address _metadataRegistry) external onlyOwner {
        if (_organizationManager == address(0) || _metadataRegistry == address(0)) {
            revert InvalidAddress();
        }
        organizationManager = IOrganizationManagerGetter(_organizationManager);
        metadataRegistry = IOrganizationMetadataRegistry(_metadataRegistry);
        emit ContractsUpdated(_organizationManager, _metadataRegistry);
    }

    /**
     * @dev Lấy đầy đủ thông tin của Organization bao gồm cả core và metadata.
     */
    function getFullOrganizationInfo(uint48 organizationId)
        external
        view
        override
        returns (FullOrganizationInfo memory)
    {
        (address owner, uint48 id, bool active, bool exists) = organizationManager.organizations(organizationId);
        if (!exists) {
            revert OrganizationNotFound();
        }

        string memory name = "";
        string memory orgAddress = "";
        string memory phoneNumber = "";

        // Tránh revert nếu chưa thiết lập Metadata (trả về các trường rỗng)
        try metadataRegistry.getOrganizationMetadata(organizationId) returns (
            OrganizationTypes.OrganizationMetadata memory meta
        ) {
            name = meta.name;
            orgAddress = meta.organizationAddress;
            phoneNumber = meta.phoneNumber;
        } catch {}

        return
            FullOrganizationInfo({
                id: id,
                owner: owner,
                active: active,
                exists: exists,
                name: name,
                organizationAddress: orgAddress,
                phoneNumber: phoneNumber
            });
    }

    /**
     * @dev Lấy đầy đủ thông tin của Branch bao gồm cả core và metadata.
     */
    function getFullBranchInfo(uint48 branchId) external view override returns (FullBranchInfo memory) {
        (address owner, uint48 organizationId, bool active, bool exists) = organizationManager.branches(branchId);
        if (!exists) {
            revert BranchNotFound();
        }

        string memory name = "";
        string memory orgAddress = "";
        string memory phoneNumber = "";
        string memory code = "";

        // Tránh revert nếu chưa thiết lập Metadata (trả về các trường rỗng)
        try metadataRegistry.getBranchMetadata(branchId) returns (BranchTypes.BranchMetadata memory meta) {
            name = meta.name;
            orgAddress = meta.organizationAddress;
            phoneNumber = meta.phoneNumber;
            code = meta.code;
        } catch {}

        return
            FullBranchInfo({
                id: branchId,
                owner: owner,
                organizationId: organizationId,
                active: active,
                exists: exists,
                name: name,
                organizationAddress: orgAddress,
                phoneNumber: phoneNumber,
                code: code
            });
    }

    /**
     * @dev Lấy danh sách đầy đủ thông tin tất cả các Branch của một Organization.
     */
    function getOrganizationBranchesFull(uint48 organizationId)
        external
        view
        override
        returns (FullBranchInfo[] memory)
    {
        uint48[] memory branchIds = organizationManager.getOrganizationBranches(organizationId);
        uint256 length = branchIds.length;

        FullBranchInfo[] memory fullBranches = new FullBranchInfo[](length);

        for (uint256 i = 0; i < length; i++) {
            fullBranches[i] = this.getFullBranchInfo(branchIds[i]);
        }

        return fullBranches;
    }
}
