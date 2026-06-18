// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {ISystemAccessControl} from "./interfaces/ISystemAccessControl.sol";
import {IModuleManager} from "./interfaces/IModuleManager.sol";
import {IOrganizationFactory} from "./interfaces/IOrganizationFactory.sol";
import {OrganizationFactoryStorage} from "./storages/OrganizationFactoryStorage.sol";

import {Organization, Branch, BranchUIState} from "../shared/types/DataTypes.sol";
import {RoleHashes} from "../shared/constants/RoleHashes.sol";
import {UnauthorizedAccess, InvalidAddress, OrgDoesNotExist, BranchDoesNotExist, ModuleNotRegistered, ModuleAlreadyEnabled, CodeAlreadyExists, ModuleNotEntitled, MismatchedBatchInputs} from "../shared/libraries/AppErrors.sol";

import {BranchBeaconProxy} from "../infrastructure/proxies/BranchBeaconProxy.sol";

contract OrganizationFactory is
    Initializable,
    UUPSUpgradeable,
    OrganizationFactoryStorage
{
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _accessControl,
        address _moduleManager
    ) public initializer {
        if (_accessControl == address(0) || _moduleManager == address(0)) {
            revert InvalidAddress();
        }

        accessControl = ISystemAccessControl(_accessControl);
        moduleManager = IModuleManager(_moduleManager);

        nextOrgId = 1;
        nextBranchId = 1;
    }

    // --- Modifiers ---
    modifier onlyManagementRole() {
        if (
            !accessControl.hasRole(RoleHashes.DEFAULT_ADMIN_ROLE, msg.sender) &&
            !accessControl.hasRole(RoleHashes.COMPANY_ADMIN_ROLE, msg.sender) &&
            !accessControl.hasRole(RoleHashes.OPS_ADMIN_ROLE, msg.sender)
        ) {
            revert UnauthorizedAccess();
        }
        _;
    }

    modifier onlyCompanyAdmin() {
        if (
            !accessControl.hasRole(RoleHashes.DEFAULT_ADMIN_ROLE, msg.sender) &&
            !accessControl.hasRole(RoleHashes.COMPANY_ADMIN_ROLE, msg.sender)
        ) {
            revert UnauthorizedAccess();
        }
        _;
    }

    // --- Core Functions ---
    function createOrganization(
        string calldata code,
        string calldata name,
        string calldata phone,
        string calldata hqAddress,
        address customerWallet
    ) external override onlyManagementRole returns (uint256) {
        if (customerWallet == address(0)) revert InvalidAddress();

        bytes32 codeHash = keccak256(abi.encodePacked(code));
        if (codeToOrgId[codeHash] != 0) revert CodeAlreadyExists();

        uint256 orgId = nextOrgId++;

        organizations[orgId] = Organization({
            id: orgId,
            walletAddress: customerWallet,
            code: code,
            storeName: name,
            phone: phone,
            storeAddress: hqAddress,
            isActive: true
        });

        codeToOrgId[codeHash] = orgId;

        emit OrganizationCreated(orgId, code, name, customerWallet);
        return orgId;
    }

    function createBranch(
        uint256 orgId,
        string calldata name
    ) external override onlyManagementRole returns (uint256) {
        if (organizations[orgId].id == 0) revert OrgDoesNotExist();

        uint256 branchId = nextBranchId++;

        branches[branchId] = Branch({
            id: branchId,
            orgId: orgId,
            name: name,
            isActive: true
        });

        emit BranchCreated(branchId, orgId, name);
        return branchId;
    }

    function grantModuleEntitlement(
        uint256 orgId,
        bytes32 parentId,
        bytes32 subId
    ) external override onlyManagementRole {
        if (organizations[orgId].id == 0) revert OrgDoesNotExist();

        (, bool isRegistered) = moduleManager.subModules(parentId, subId);
        if (!isRegistered) revert ModuleNotRegistered(subId);

        orgModuleEntitlements[orgId][parentId][subId] = true;

        emit ModuleEntitlementGranted(orgId, parentId, subId);
    }

    function enableModule(
        uint256 branchId,
        bytes32 parentId,
        bytes32 subId,
        bytes calldata initData
    ) external override onlyCompanyAdmin returns (address) {
        return _enableModuleInternal(branchId, parentId, subId, initData);
    }

    function enableModulesBatch(
        uint256 branchId,
        bytes32[] calldata parentIds,
        bytes32[] calldata subIds,
        bytes[] calldata initDatas
    ) external override onlyCompanyAdmin returns (address[] memory) {
        if (parentIds.length != initDatas.length || parentIds.length != subIds.length)
            revert MismatchedBatchInputs();
        if (parentIds.length == 0) revert InvalidAddress();

        address[] memory proxyAddresses = new address[](parentIds.length);

        for (uint256 i = 0; i < parentIds.length; i++) {
            proxyAddresses[i] = _enableModuleInternal(
                branchId,
                parentIds[i],
                subIds[i],
                initDatas[i]
            );
        }

        return proxyAddresses;
    }

    function _enableModuleInternal(
        uint256 branchId,
        bytes32 parentId,
        bytes32 subId,
        bytes calldata initData
    ) private returns (address) {
        uint256 orgId = branches[branchId].orgId;
        if (orgId == 0) revert BranchDoesNotExist();

        if (!orgModuleEntitlements[orgId][parentId][subId]) revert ModuleNotEntitled();

        if (branchModules[branchId][parentId][subId] != address(0))
            revert ModuleAlreadyEnabled();

        (address beaconAddress, bool isRegistered) = moduleManager.subModules(
            parentId,
            subId
        );
        if (!isRegistered || beaconAddress == address(0))
            revert ModuleNotRegistered(subId);

        BranchBeaconProxy newProxy = new BranchBeaconProxy(
            beaconAddress,
            initData,
            branchId,
            orgId
        );

        address proxyAddress = address(newProxy);
        branchModules[branchId][parentId][subId] = proxyAddress;

        emit ModuleEnabled(branchId, parentId, subId, proxyAddress);

        return proxyAddress;
    }

    // --- UI Aggregation Functions ---

    /**
     * @dev Trả về mảng boolean trạng thái sở hữu module của một Tổ chức.
     */
    function getOrgEntitlementsBatch(
        uint256 orgId,
        bytes32[] calldata queryParentIds,
        bytes32[] calldata querySubIds
    ) external view override returns (bool[] memory) {
        if (queryParentIds.length != querySubIds.length) revert MismatchedBatchInputs();
        bool[] memory entitlements = new bool[](queryParentIds.length);
        for (uint256 i = 0; i < queryParentIds.length; i++) {
            entitlements[i] = orgModuleEntitlements[orgId][queryParentIds[i]][querySubIds[i]];
        }
        return entitlements;
    }

    /**
     * @dev Quét danh sách chi nhánh và trả về toàn bộ trạng thái Bật/Tắt module theo định dạng Struct.
     */
    function getBranchesModuleStatus(
        uint256[] calldata branchIds,
        bytes32[] calldata queryParentIds,
        bytes32[] calldata querySubIds
    ) external view override returns (BranchUIState[] memory) {
        if (queryParentIds.length != querySubIds.length) revert MismatchedBatchInputs();
        BranchUIState[] memory result = new BranchUIState[](branchIds.length);

        for (uint256 i = 0; i < branchIds.length; i++) {
            uint256 bId = branchIds[i];
            Branch memory b = branches[bId];

            bool[] memory mStatus = new bool[](queryParentIds.length);
            for (uint256 j = 0; j < queryParentIds.length; j++) {
                // Nếu address tồn tại khác 0, nghĩa là module đang được kích hoạt tại chi nhánh này
                mStatus[j] =
                    branchModules[bId][queryParentIds[j]][querySubIds[j]] != address(0);
            }

            result[i] = BranchUIState({
                branchId: b.id,
                name: b.name,
                isActive: b.isActive,
                moduleStatuses: mStatus
            });
        }

        return result;
    }

    function _authorizeUpgrade(address newImplementation) internal override {
        if (!accessControl.hasRole(bytes32(0), msg.sender)) {
            revert UnauthorizedAccess();
        }
    }
}
