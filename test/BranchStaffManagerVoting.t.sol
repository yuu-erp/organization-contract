// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import {SystemAccessControl} from "../src/core/SystemAccessControl.sol";
import {OrganizationManager} from "../src/core/OrganizationManager.sol";
import {ModuleRegistry} from "../src/registry/ModuleRegistry.sol";
import {BranchModuleManager} from "../src/core/BranchModuleManager.sol";
import {BranchStaffManager} from "../src/core/BranchStaffManager.sol";
import {BranchGovernanceManager} from "../src/core/BranchGovernanceManager.sol";
import {IBranchGovernanceManager} from "../src/core/interfaces/IBranchGovernanceManager.sol";
import {GovernanceTypes} from "../src/types/GovernanceTypes.sol";
import {StaffMetadataRegistry} from "../src/registry/StaffMetadataRegistry.sol";
import {IStaffMetadataRegistry} from "../src/registry/interfaces/IStaffMetadataRegistry.sol";
import {StaffTypes} from "../src/types/StaffTypes.sol";
import {RoleHashes} from "../src/core/constants/RoleHashes.sol";

contract BranchStaffManagerVotingTest is Test {
    SystemAccessControl sacProxy;
    OrganizationManager omProxy;
    ModuleRegistry mrProxy;
    BranchModuleManager bmmProxy;
    StaffMetadataRegistry smrProxy;

    address deployer = address(0x1);
    address orgOwner = address(0x2);
    address branchCoOwner = address(0x3);
    address branchCoOwner2 = address(0x33);
    address branchManager = address(0x4);
    address staff1 = address(0x5);
    address attacker = address(0x7);

    uint48 orgId;
    uint48 branchId;

    BranchStaffManager staffManager;
    BranchGovernanceManager governanceManager;

    function setUp() public {
        vm.startPrank(deployer);

        // 1. Deploy SystemAccessControl (UUPS Proxy)
        SystemAccessControl sacImpl = new SystemAccessControl();
        sacProxy = SystemAccessControl(
            address(new ERC1967Proxy(address(sacImpl), abi.encodeCall(SystemAccessControl.initialize, (deployer))))
        );
        sacProxy.grantRole(RoleHashes.PLATFORM_ADMIN_ROLE, deployer);

        // 2. Deploy OrganizationManager (UUPS Proxy)
        OrganizationManager omImpl = new OrganizationManager();
        omProxy = OrganizationManager(
            address(
                new ERC1967Proxy(address(omImpl), abi.encodeCall(OrganizationManager.initialize, (address(sacProxy))))
            )
        );

        // 3. Deploy ModuleRegistry (UUPS Proxy)
        ModuleRegistry mrImpl = new ModuleRegistry();
        mrProxy = ModuleRegistry(
            address(new ERC1967Proxy(address(mrImpl), abi.encodeCall(ModuleRegistry.initialize, (address(sacProxy)))))
        );

        // 4. Deploy BranchStaffManager implementation + UpgradeableBeacon
        BranchStaffManager staffManagerImpl = new BranchStaffManager();
        UpgradeableBeacon staffBeacon = new UpgradeableBeacon(address(staffManagerImpl), deployer);

        // 5. Deploy BranchGovernanceManager implementation + UpgradeableBeacon
        BranchGovernanceManager governanceImpl = new BranchGovernanceManager();
        UpgradeableBeacon govBeacon = new UpgradeableBeacon(address(governanceImpl), deployer);

        // 6. Deploy BranchModuleManager (UUPS Proxy)
        BranchModuleManager bmmImpl = new BranchModuleManager();
        bmmProxy = BranchModuleManager(
            address(
                new ERC1967Proxy(
                    address(bmmImpl),
                    abi.encodeCall(
                        BranchModuleManager.initialize,
                        (address(sacProxy), address(omProxy), address(mrProxy), address(staffBeacon))
                    )
                )
            )
        );

        // 7. Deploy StaffMetadataRegistry (UUPS Proxy)
        StaffMetadataRegistry smrImpl = new StaffMetadataRegistry();
        smrProxy = StaffMetadataRegistry(
            address(
                new ERC1967Proxy(
                    address(smrImpl),
                    abi.encodeCall(
                        StaffMetadataRegistry.initialize, (address(sacProxy), address(omProxy), address(bmmProxy))
                    )
                )
            )
        );

        sacProxy.grantRole(RoleHashes.PLATFORM_ADMIN_ROLE, address(omProxy));
        sacProxy.grantRole(RoleHashes.PLATFORM_ADMIN_ROLE, address(bmmProxy));

        omProxy.setRegistryAndManager(address(mrProxy), address(bmmProxy));

        // Configure Governance Beacon and StaffMetadataRegistry in BranchModuleManager
        bmmProxy.setGovernanceAndRegistry(address(govBeacon), address(smrProxy));

        // Setup Organization and Branch
        bytes32[] memory emptyModules = new bytes32[](0);
        orgId = uint48(omProxy.createOrganization(orgOwner, emptyModules));
        branchId = omProxy.createBranch(orgId, emptyModules); 

        address staffManagerAddr = bmmProxy.getBranchStaffManager(branchId);
        staffManager = BranchStaffManager(staffManagerAddr);

        address govAddr = bmmProxy.branchGovernanceManagers(branchId);
        governanceManager = BranchGovernanceManager(govAddr);

        vm.stopPrank();
    }

    function test_DirectAdminActionsWithoutCoOwners() public {
        vm.startPrank(orgOwner);

        // 1. Direct role assignment works when coOwnerCount is 0
        staffManager.setGlobalProfile(branchCoOwner, 1, 0); // ROLE_CO_OWNER = 1
        assertEq(staffManager.coOwnerCount(), 1);

        // 2. Direct metadata update works when target is not co-owner yet
        smrProxy.setStaffMetadata(branchId, branchManager, "Direct Manager", "0912345", "direct_avatar");

        // Now coOwnerCount is 1. Let's try to add another co-owner directly. It should revert.
        vm.expectRevert("RequiresProposal");
        staffManager.setGlobalProfile(branchCoOwner2, 1, 0);

        vm.stopPrank();
    }

    function test_VotingToAddCoOwnerAndManager() public {
        // 1. Add first co-owner directly (coOwnerCount becomes 1)
        vm.prank(orgOwner);
        staffManager.setGlobalProfile(branchCoOwner, 1, 0);

        // 2. Try to add manager directly -> fails
        vm.startPrank(orgOwner);
        vm.expectRevert("RequiresProposal");
        staffManager.setGlobalProfile(branchManager, 2, 0);

        // 3. Create proposal to add manager (using governanceManager)
        uint256 propId = governanceManager.createProposal(
            GovernanceTypes.ProposalType.AddOrUpdateProfile,
            branchManager,
            2, // ROLE_MANAGER
            0,
            bytes32(0),
            0,
            "",
            "",
            ""
        );

        // Vote 1: Org Owner
        governanceManager.voteProposal(propId, true);
        
        // Try to execute before majority -> fails
        vm.expectRevert(IBranchGovernanceManager.ProposalCannotBeExecuted.selector);
        governanceManager.executeProposal(propId, "", "", "");
        vm.stopPrank();

        // Vote 2: Co-Owner
        vm.prank(branchCoOwner);
        governanceManager.voteProposal(propId, true);

        // Execute -> succeeds
        vm.prank(orgOwner);
        governanceManager.executeProposal(propId, "", "", "");

        (uint8 role, ) = staffManager.staffProfiles(branchManager);
        assertEq(role, 2); // ROLE_MANAGER
    }

    function test_MetadataVotingRequirement() public {
        // 1. Add co-owner directly
        vm.prank(orgOwner);
        staffManager.setGlobalProfile(branchCoOwner, 1, 0);

        // 2. Try to update co-owner metadata directly -> fails
        vm.startPrank(orgOwner);
        vm.expectRevert(StaffMetadataRegistry.RequiresProposal.selector);
        smrProxy.setStaffMetadata(branchId, branchCoOwner, "CoOwner Name", "123456", "avatar");

        // 3. Create proposal to update metadata
        uint256 propId = governanceManager.createProposal(
            GovernanceTypes.ProposalType.UpdateMetadata,
            branchCoOwner,
            0,
            0,
            bytes32(0),
            0,
            "CoOwner Voted Name",
            "12345678",
            "avatar_voted"
        );

        governanceManager.voteProposal(propId, true);
        vm.stopPrank();

        vm.prank(branchCoOwner);
        governanceManager.voteProposal(propId, true);

        // Execute proposal with matching payload -> updates metadata in StaffMetadataRegistry
        vm.prank(orgOwner);
        governanceManager.executeProposal(propId, "CoOwner Voted Name", "12345678", "avatar_voted");

        StaffTypes.StaffMetadata memory meta = smrProxy.getStaffMetadata(branchId, branchCoOwner);
        assertEq(meta.name, "CoOwner Voted Name");
        assertEq(meta.phoneNumber, "12345678");
        assertEq(meta.avatar, "avatar_voted");
    }

    function test_CancelProposal() public {
        vm.prank(orgOwner);
        staffManager.setGlobalProfile(branchCoOwner, 1, 0);

        vm.startPrank(branchCoOwner);
        uint256 propId = governanceManager.createProposal(
            GovernanceTypes.ProposalType.AddOrUpdateProfile,
            branchManager,
            2,
            0,
            bytes32(0),
            0,
            "",
            "",
            ""
        );

        // Attacker attempts to cancel -> fails
        vm.stopPrank();
        vm.prank(attacker);
        vm.expectRevert(IBranchGovernanceManager.Unauthorized.selector);
        governanceManager.cancelProposal(propId);

        // Creator (branchCoOwner) cancels -> succeeds
        vm.prank(branchCoOwner);
        governanceManager.cancelProposal(propId);
    }

    function test_VotingDurationExpiration() public {
        vm.prank(orgOwner);
        staffManager.setGlobalProfile(branchCoOwner, 1, 0);

        vm.startPrank(orgOwner);
        uint256 propId = governanceManager.createProposal(
            GovernanceTypes.ProposalType.AddOrUpdateProfile,
            branchManager,
            2,
            0,
            bytes32(0),
            0,
            "",
            "",
            ""
        );

        // Warp time beyond 7 days
        skip(7 days + 1);

        // Voting fails with ProposalExpired
        vm.expectRevert(IBranchGovernanceManager.ProposalExpired.selector);
        governanceManager.voteProposal(propId, true);
        vm.stopPrank();
    }
}
