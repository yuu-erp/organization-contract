// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import {SystemAccessControl} from "../src/core/SystemAccessControl.sol";
import {OrganizationManager} from "../src/core/OrganizationManager.sol";
import {ModuleRegistry} from "../src/core/ModuleRegistry.sol";
import {BranchModuleManager} from "../src/core/BranchModuleManager.sol";
import {BranchStaffManager} from "../src/core/BranchStaffManager.sol";
import {StaffMetadataRegistry} from "../src/registry/StaffMetadataRegistry.sol";
import {IStaffMetadataRegistry} from "../src/registry/interfaces/IStaffMetadataRegistry.sol";
import {StaffTypes} from "../src/types/StaffTypes.sol";
import {RoleHashes} from "../src/core/constants/RoleHashes.sol";
import {BranchGovernanceManager} from "../src/core/BranchGovernanceManager.sol";

contract StaffMetadataRegistryTest is Test {
    SystemAccessControl sacProxy;
    OrganizationManager omProxy;
    ModuleRegistry mrProxy;
    BranchModuleManager bmmProxy;
    StaffMetadataRegistry smrProxy;

    address deployer = address(0x1);
    address orgOwner = address(0x2);
    address branchCoOwner = address(0x3);
    address branchManager = address(0x4);
    address staff1 = address(0x5);
    address staff2 = address(0x6);
    address attacker = address(0x7);

    uint48 orgId;
    uint48 branchId;

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

        // Deploy BranchGovernanceManager implementation + UpgradeableBeacon
        BranchGovernanceManager governanceImpl = new BranchGovernanceManager();
        UpgradeableBeacon govBeacon = new UpgradeableBeacon(address(governanceImpl), deployer);

        // 5. Deploy BranchModuleManager (UUPS Proxy)
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

        // 6. Deploy StaffMetadataRegistry (UUPS Proxy)
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

        // Configure Governance Beacon and StaffMetadataRegistry in BranchModuleManager
        bmmProxy.setGovernanceAndRegistry(address(govBeacon), address(smrProxy));

        // Grant roles to contracts
        sacProxy.grantRole(RoleHashes.PLATFORM_ADMIN_ROLE, address(omProxy));
        sacProxy.grantRole(RoleHashes.PLATFORM_ADMIN_ROLE, address(bmmProxy));

        // Link OrganizationManager to registry & manager
        omProxy.setRegistryAndManager(address(mrProxy), address(bmmProxy));

        // 7. Setup Organization and Branch
        bytes32[] memory emptyModules = new bytes32[](0);
        orgId = uint48(omProxy.createOrganization(orgOwner, emptyModules));
        branchId = omProxy.createBranch(orgId, emptyModules);

        vm.stopPrank();

        // 9. Assign Roles in BranchStaffManager
        address staffManagerAddr = bmmProxy.getBranchStaffManager(branchId);
        BranchStaffManager staffManager = BranchStaffManager(staffManagerAddr);

        vm.startPrank(orgOwner);
        // Manager: role = 2
        staffManager.setGlobalProfile(branchManager, 2, 0);
        // Co-owner: role = 1
        staffManager.setGlobalProfile(branchCoOwner, 1, 0);
        // Staff: role = 3
        staffManager.setGlobalProfile(staff1, 3, 0);
        staffManager.setGlobalProfile(staff2, 3, 0);
        vm.stopPrank();
    }

    function test_StaffCanUpdateTheirOwnMetadata() public {
        vm.startPrank(staff1);

        smrProxy.setStaffMetadata(branchId, staff1, "Staff One", "0999999999", "avatar_hash_1");

        StaffTypes.StaffMetadata memory meta = smrProxy.getStaffMetadata(branchId, staff1);
        assertEq(meta.name, "Staff One");
        assertEq(meta.phoneNumber, "0999999999");
        assertEq(meta.avatar, "avatar_hash_1");

        vm.stopPrank();
    }

    function test_OwnerCanUpdateStaffMetadata() public {
        vm.startPrank(orgOwner);

        smrProxy.setStaffMetadata(branchId, staff1, "Staff Updated By Owner", "0111111111", "avatar_hash_owner");

        StaffTypes.StaffMetadata memory meta = smrProxy.getStaffMetadata(branchId, staff1);
        assertEq(meta.name, "Staff Updated By Owner");

        vm.stopPrank();
    }

    function test_CoOwnerCanUpdateStaffMetadata() public {
        vm.startPrank(branchCoOwner);

        smrProxy.setStaffMetadata(branchId, staff1, "Staff Updated By CoOwner", "0222222222", "avatar_hash_coowner");

        StaffTypes.StaffMetadata memory meta = smrProxy.getStaffMetadata(branchId, staff1);
        assertEq(meta.name, "Staff Updated By CoOwner");

        vm.stopPrank();
    }

    function test_ManagerCanUpdateStaffMetadata() public {
        vm.startPrank(branchManager);

        smrProxy.setStaffMetadata(branchId, staff1, "Staff Updated By Manager", "0333333333", "avatar_hash_manager");

        StaffTypes.StaffMetadata memory meta = smrProxy.getStaffMetadata(branchId, staff1);
        assertEq(meta.name, "Staff Updated By Manager");

        vm.stopPrank();
    }

    function test_SystemAdminCanUpdateStaffMetadata() public {
        vm.startPrank(deployer);

        smrProxy.setStaffMetadata(branchId, staff1, "Staff Updated By Admin", "0444444444", "avatar_hash_admin");

        StaffTypes.StaffMetadata memory meta = smrProxy.getStaffMetadata(branchId, staff1);
        assertEq(meta.name, "Staff Updated By Admin");

        vm.stopPrank();
    }

    function test_RevertWhenAttackerAttemptsToUpdateStaffMetadata() public {
        vm.startPrank(attacker);

        vm.expectRevert(StaffMetadataRegistry.Unauthorized.selector);
        smrProxy.setStaffMetadata(branchId, staff1, "Attacker name", "0666666666", "avatar_hash_attacker");

        vm.stopPrank();
    }

    function test_RevertWhenStaffAttemptsToUpdateAnotherStaffMetadata() public {
        vm.startPrank(staff1);

        vm.expectRevert(StaffMetadataRegistry.Unauthorized.selector);
        smrProxy.setStaffMetadata(branchId, staff2, "Modified by Peer", "0555555555", "avatar_hash_peer");

        vm.stopPrank();
    }
}
