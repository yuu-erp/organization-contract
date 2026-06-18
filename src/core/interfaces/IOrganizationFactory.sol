// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Import Structs từ Shared Kernel
import {Organization, Branch, BranchUIState} from "../../shared/types/DataTypes.sol";

/**
 * @title IOrganizationFactory
 * @dev Interface quản lý việc tạo Tổ chức, Chi nhánh và cấp phát BeaconProxy.
 */
interface IOrganizationFactory {
    // --- Events ---
    event OrganizationCreated(
        uint256 indexed orgId,
        string code,
        string name,
        address indexed customerWallet
    );

    event BranchCreated(
        uint256 indexed branchId,
        uint256 indexed orgId,
        string name
    );

    event ModuleEntitlementGranted(
        uint256 indexed orgId,
        bytes32 indexed parentId,
        bytes32 indexed subId
    );

    event ModuleEnabled(
        uint256 indexed branchId,
        bytes32 indexed parentId,
        bytes32 indexed subId,
        address proxyAddress
    );

    // --- Getter Functions (Tự động sinh bởi compiler từ Storage) ---
    function nextOrgId() external view returns (uint256);

    function nextBranchId() external view returns (uint256);

    function organizations(
        uint256 orgId
    )
        external
        view
        returns (
            uint256 id,
            address walletAddress,
            string memory code,
            string memory storeName,
            string memory phone,
            string memory storeAddress,
            bool isActive
        );

    function branches(
        uint256 branchId
    )
        external
        view
        returns (uint256 id, uint256 orgId, string memory name, bool isActive);

    function branchModules(
        uint256 branchId,
        bytes32 parentId,
        bytes32 subId
    ) external view returns (address proxyAddress);

    function codeToOrgId(
        bytes32 codeHash
    ) external view returns (uint256 orgId);

    function orgModuleEntitlements(
        uint256 orgId,
        bytes32 parentId,
        bytes32 subId
    ) external view returns (bool isEntitled);

    // --- Core Functions ---
    function createOrganization(
        string calldata code,
        string calldata name,
        string calldata phone,
        string calldata hqAddress,
        address customerWallet
    ) external returns (uint256);

    function createBranch(
        uint256 orgId,
        string calldata name
    ) external returns (uint256);

    function grantModuleEntitlement(
        uint256 orgId,
        bytes32 parentId,
        bytes32 subId
    ) external;

    function enableModule(
        uint256 branchId,
        bytes32 parentId,
        bytes32 subId,
        bytes calldata initData
    ) external returns (address);

    function enableModulesBatch(
        uint256 branchId,
        bytes32[] calldata parentIds,
        bytes32[] calldata subIds,
        bytes[] calldata initDatas
    ) external returns (address[] memory);

    // --- UI Aggregation Functions ---
    function getOrgEntitlementsBatch(
        uint256 orgId,
        bytes32[] calldata queryParentIds,
        bytes32[] calldata querySubIds
    ) external view returns (bool[] memory);

    function getBranchesModuleStatus(
        uint256[] calldata branchIds,
        bytes32[] calldata queryParentIds,
        bytes32[] calldata querySubIds
    ) external view returns (BranchUIState[] memory);
}
