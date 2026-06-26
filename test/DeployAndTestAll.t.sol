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

import {MeosRoot} from "../src/modules/meos/MeosRoot.sol";
import {PCManager} from "../src/modules/meos/PCManager.sol";
import {AccountManager} from "../src/modules/meos/AccountManager.sol";
import {BranchContextUpgradeable} from "../src/modules/base/BranchContextUpgradeable.sol";
import {MeosFactory} from "../src/modules/meos/MeosFactory.sol";
import {IqrRoot} from "../src/modules/iqr/IqrRoot.sol";
import {POSManager} from "../src/modules/iqr/POSManager.sol";
import {IqrFactory} from "../src/modules/iqr/IqrFactory.sol";
import {LoyaltyRoot} from "../src/modules/loyalty/LoyaltyRoot.sol";
import {PointManager} from "../src/modules/loyalty/PointManager.sol";
import {LoyaltyFactory} from "../src/modules/loyalty/LoyaltyFactory.sol";

import {ModuleKeys} from "../src/core/constants/ModuleKeys.sol";
import {RoleHashes} from "../src/core/constants/RoleHashes.sol";

// Hợp đồng logic V2 để kiểm tra nâng cấp
contract PCManagerV2 is PCManager {
    function doublePCs() external {
        activePCs = activePCs * 2;
    }
}

contract POSManagerV2 is POSManager {
    function tripleOrders() external {
        totalOrders = totalOrders * 3;
    }
}

contract PointManagerV2 is PointManager {
    function resetPoints(address user) external {
        userPoints[user] = 0;
    }
}

contract DeployAndTestAllTest is Test {
    SystemAccessControl sacProxy;
    OrganizationManager omProxy;
    ModuleRegistry mrProxy;
    BranchModuleManager bmmProxy;

    UpgradeableBeacon pcManagerBeacon;
    UpgradeableBeacon accountManagerBeacon;
    UpgradeableBeacon posManagerBeacon;
    UpgradeableBeacon pointManagerBeacon;

    address deployer = address(0x1);
    address orgOwner = address(0x2);

    function setUp() public {
        vm.startPrank(deployer);

        // 1. Deploy SystemAccessControl (UUPS Proxy)
        SystemAccessControl sacImpl = new SystemAccessControl();
        sacProxy = SystemAccessControl(
            address(new ERC1967Proxy(address(sacImpl), abi.encodeCall(SystemAccessControl.initialize, (deployer))))
        );

        // Grant Roles to deployer
        sacProxy.grantRole(RoleHashes.PLATFORM_ADMIN_ROLE, deployer);
        sacProxy.grantRole(RoleHashes.OPS_ADMIN_ROLE, deployer);

        // 2. Deploy OrganizationManager (UUPS Proxy)
        OrganizationManager omImpl = new OrganizationManager();
        omProxy = OrganizationManager(
            address(new ERC1967Proxy(address(omImpl), abi.encodeCall(OrganizationManager.initialize, (address(sacProxy)))))
        );

        // 3. Deploy ModuleRegistry (UUPS Proxy)
        ModuleRegistry mrImpl = new ModuleRegistry();
        mrProxy = ModuleRegistry(
            address(new ERC1967Proxy(address(mrImpl), abi.encodeCall(ModuleRegistry.initialize, (address(sacProxy)))))
        );

        // 4. Deploy BranchStaffManager implementation + UpgradeableBeacon
        BranchStaffManager staffManagerImpl = new BranchStaffManager();
        UpgradeableBeacon staffBeacon = new UpgradeableBeacon(address(staffManagerImpl), deployer);

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

        // Grant roles to contracts
        sacProxy.grantRole(RoleHashes.PLATFORM_ADMIN_ROLE, address(omProxy));
        sacProxy.grantRole(RoleHashes.PLATFORM_ADMIN_ROLE, address(bmmProxy));

        // 6. Link OrganizationManager to ModuleRegistry and BranchModuleManager
        omProxy.setRegistryAndManager(address(mrProxy), address(bmmProxy));

        // 7. Deploy Module Beacons and Factories
        // MEOS Root Beacon
        MeosRoot meosImpl = new MeosRoot();
        UpgradeableBeacon meosBeacon = new UpgradeableBeacon(address(meosImpl), deployer);

        // Deploy Sub-contracts Beacons
        pcManagerBeacon = new UpgradeableBeacon(address(new PCManager()), deployer);
        accountManagerBeacon = new UpgradeableBeacon(address(new AccountManager()), deployer);
        posManagerBeacon = new UpgradeableBeacon(address(new POSManager()), deployer);
        pointManagerBeacon = new UpgradeableBeacon(address(new PointManager()), deployer);

        MeosFactory meosFactory = new MeosFactory(
            address(meosBeacon),
            address(pcManagerBeacon),
            address(accountManagerBeacon),
            address(bmmProxy)
        );

        // IQR
        IqrRoot iqrImpl = new IqrRoot();
        UpgradeableBeacon iqrBeacon = new UpgradeableBeacon(address(iqrImpl), deployer);
        IqrFactory iqrFactory = new IqrFactory(address(iqrBeacon), address(posManagerBeacon), address(bmmProxy));

        // LOYALTY
        LoyaltyRoot loyaltyImpl = new LoyaltyRoot();
        UpgradeableBeacon loyaltyBeacon = new UpgradeableBeacon(address(loyaltyImpl), deployer);
        LoyaltyFactory loyaltyFactory = new LoyaltyFactory(address(loyaltyBeacon), address(pointManagerBeacon), address(bmmProxy));

        // 8. Register Modules in ModuleRegistry
        mrProxy.registerModule(ModuleKeys.MODULE_MEOS, "MEOS", address(meosFactory));
        mrProxy.registerModule(ModuleKeys.MODULE_IQR, "IQR", address(iqrFactory));
        mrProxy.registerModule(ModuleKeys.MODULE_LOYALTY, "LOYALTY", address(loyaltyFactory));

        vm.stopPrank();
    }

    function test_BranchModuleOrchestrationFlow() public {
        vm.startPrank(deployer);

        // 1. Tạo 1 Organization với 3 modules (MEOS, IQR, LOYALTY)
        bytes32[] memory orgModules = new bytes32[](3);
        orgModules[0] = ModuleKeys.MODULE_MEOS;
        orgModules[1] = ModuleKeys.MODULE_IQR;
        orgModules[2] = ModuleKeys.MODULE_LOYALTY;

        uint256 orgId = omProxy.createOrganization(orgOwner, orgModules);
        assertEq(orgId, 1);

        // 2. Tạo Branch 1: Bật FULL 3 modules (MEOS, IQR, LOYALTY)
        bytes32[] memory branch1Modules = new bytes32[](3);
        branch1Modules[0] = ModuleKeys.MODULE_MEOS;
        branch1Modules[1] = ModuleKeys.MODULE_IQR;
        branch1Modules[2] = ModuleKeys.MODULE_LOYALTY;
        uint256 branchId1 = omProxy.createBranch(orgId, branch1Modules);
        assertEq(branchId1, 1);

        // 3. Tạo Branch 2: Bật MEOS và LOYALTY (Không bật IQR)
        bytes32[] memory branch2Modules = new bytes32[](2);
        branch2Modules[0] = ModuleKeys.MODULE_MEOS;
        branch2Modules[1] = ModuleKeys.MODULE_LOYALTY;
        uint256 branchId2 = omProxy.createBranch(orgId, branch2Modules);
        assertEq(branchId2, 2);

        vm.stopPrank();

        // 4. Kiểm tra các Proxy được deploy đúng
        address branch1Meos = bmmProxy.getModuleRoot(branchId1, ModuleKeys.MODULE_MEOS);
        address branch1Iqr = bmmProxy.getModuleRoot(branchId1, ModuleKeys.MODULE_IQR);
        address branch1Loyalty = bmmProxy.getModuleRoot(branchId1, ModuleKeys.MODULE_LOYALTY);

        address branch2Meos = bmmProxy.getModuleRoot(branchId2, ModuleKeys.MODULE_MEOS);
        address branch2Iqr = bmmProxy.getModuleRoot(branchId2, ModuleKeys.MODULE_IQR);
        address branch2Loyalty = bmmProxy.getModuleRoot(branchId2, ModuleKeys.MODULE_LOYALTY);

        // Assert Branch 1
        assertTrue(branch1Meos != address(0), "Branch 1 MEOS must be deployed");
        assertTrue(branch1Iqr != address(0), "Branch 1 IQR must be deployed");
        assertTrue(branch1Loyalty != address(0), "Branch 1 LOYALTY must be deployed");

        // Assert Branch 2
        assertTrue(branch2Meos != address(0), "Branch 2 MEOS must be deployed");
        assertTrue(branch2Iqr == address(0), "Branch 2 IQR must NOT be deployed");
        assertTrue(branch2Loyalty != address(0), "Branch 2 LOYALTY must be deployed");

        // Verify sub-contracts inside Meos Root are deployed
        address branch1PC = MeosRoot(branch1Meos).pcManager();
        address branch1Acc = MeosRoot(branch1Meos).accountManager();
        assertTrue(branch1PC != address(0), "Branch 1 PCManager must be deployed");
        assertTrue(branch1Acc != address(0), "Branch 1 AccountManager must be deployed");

        // Verify sub-contracts inside Iqr and Loyalty are deployed
        address branch1POS = IqrRoot(branch1Iqr).posManager();
        address branch1Point = LoyaltyRoot(branch1Loyalty).pointManager();
        assertTrue(branch1POS != address(0), "Branch 1 POSManager must be deployed");
        assertTrue(branch1Point != address(0), "Branch 1 PointManager must be deployed");

        console2.log("--- TEST SUCCESSFUL ---");
    }

    function test_UpgradePCManagerFlow() public {
        vm.startPrank(deployer);

        // 1. Tạo 1 Organization và Branch bật module MEOS
        bytes32[] memory orgModules = new bytes32[](1);
        orgModules[0] = ModuleKeys.MODULE_MEOS;
        uint256 orgId = omProxy.createOrganization(orgOwner, orgModules);
        uint256 branchId = omProxy.createBranch(orgId, orgModules);

        address meosRoot = bmmProxy.getModuleRoot(branchId, ModuleKeys.MODULE_MEOS);
        address pcManagerProxy = MeosRoot(meosRoot).pcManager();

        // 2. Gọi addPC() trên proxy bản cũ
        PCManager(pcManagerProxy).addPC();
        assertEq(PCManager(pcManagerProxy).activePCs(), 1);

        // 3. Thực hiện nâng cấp Beacon của PCManager lên logic V2 (thêm doublePCs)
        PCManagerV2 pcManagerV2Impl = new PCManagerV2();
        pcManagerBeacon.upgradeTo(address(pcManagerV2Impl));

        // 4. Kiểm tra trạng thái cũ (activePCs) vẫn giữ nguyên là 1
        assertEq(PCManagerV2(pcManagerProxy).activePCs(), 1);

        // 5. Gọi hàm mới doublePCs() trên proxy cũ
        PCManagerV2(pcManagerProxy).doublePCs();
        
        // 6. Kết quả nhân đôi thành công = 2
        assertEq(PCManagerV2(pcManagerProxy).activePCs(), 2);

        console2.log("--- UPGRADE PC TEST PASSED ---");
        vm.stopPrank();
    }

    function test_UpgradePOSAndPointManagers() public {
        vm.startPrank(deployer);

        bytes32[] memory orgModules = new bytes32[](2);
        orgModules[0] = ModuleKeys.MODULE_IQR;
        orgModules[1] = ModuleKeys.MODULE_LOYALTY;
        uint256 orgId = omProxy.createOrganization(orgOwner, orgModules);
        uint256 branchId = omProxy.createBranch(orgId, orgModules);

        address iqrRoot = bmmProxy.getModuleRoot(branchId, ModuleKeys.MODULE_IQR);
        address loyaltyRoot = bmmProxy.getModuleRoot(branchId, ModuleKeys.MODULE_LOYALTY);

        address posManagerProxy = IqrRoot(iqrRoot).posManager();
        address pointManagerProxy = LoyaltyRoot(loyaltyRoot).pointManager();

        // Check original functions
        POSManager(posManagerProxy).createOrder();
        assertEq(POSManager(posManagerProxy).totalOrders(), 1);

        PointManager(pointManagerProxy).addPoints(address(0x123), 100);
        assertEq(PointManager(pointManagerProxy).userPoints(address(0x123)), 100);

        // Upgrade POSManager
        posManagerBeacon.upgradeTo(address(new POSManagerV2()));
        POSManagerV2(posManagerProxy).tripleOrders();
        assertEq(POSManagerV2(posManagerProxy).totalOrders(), 3);

        // Upgrade PointManager
        pointManagerBeacon.upgradeTo(address(new PointManagerV2()));
        PointManagerV2(pointManagerProxy).resetPoints(address(0x123));
        assertEq(PointManagerV2(pointManagerProxy).userPoints(address(0x123)), 0);

        console2.log("--- UPGRADE POS/POINT TEST PASSED ---");
        vm.stopPrank();
    }

    function test_RevertWhenModuleDisabled() public {
        vm.startPrank(deployer);

        // 1. Tạo 1 Organization và Branch bật module MEOS
        bytes32[] memory orgModules = new bytes32[](1);
        orgModules[0] = ModuleKeys.MODULE_MEOS;
        uint256 orgId = omProxy.createOrganization(orgOwner, orgModules);
        uint256 branchId = omProxy.createBranch(orgId, orgModules);

        address meosRoot = bmmProxy.getModuleRoot(branchId, ModuleKeys.MODULE_MEOS);
        address pcManagerProxy = MeosRoot(meosRoot).pcManager();
        address accountManagerProxy = MeosRoot(meosRoot).accountManager();

        // Check adding PC works when enabled
        PCManager(pcManagerProxy).addPC();
        assertEq(PCManager(pcManagerProxy).activePCs(), 1);

        // Check registering user works when enabled
        AccountManager(accountManagerProxy).registerUser("user1", address(0x123));
        assertEq(AccountManager(accountManagerProxy).usernameToWallet("user1"), address(0x123));

        // 2. Disable module MEOS
        bmmProxy.disableModule(branchId, ModuleKeys.MODULE_MEOS);

        // 3. PCManager.addPC should revert now
        vm.expectRevert(BranchContextUpgradeable.ModuleDisabled.selector);
        PCManager(pcManagerProxy).addPC();

        // 4. AccountManager.registerUser should revert now
        vm.expectRevert(BranchContextUpgradeable.ModuleDisabled.selector);
        AccountManager(accountManagerProxy).registerUser("user2", address(0x456));

        // 5. Re-enable module MEOS
        bmmProxy.enableModule(branchId, ModuleKeys.MODULE_MEOS);

        // Should work again
        PCManager(pcManagerProxy).addPC();
        assertEq(PCManager(pcManagerProxy).activePCs(), 2);

        AccountManager(accountManagerProxy).registerUser("user2", address(0x456));
        assertEq(AccountManager(accountManagerProxy).usernameToWallet("user2"), address(0x456));

        vm.stopPrank();
    }

    function test_RevertAttackerDeployDirectly() public {
        address attacker = address(0x666);
        vm.startPrank(attacker);

        // MEOS Factory deployment directly should fail
        address meosFactory = mrProxy.getModuleFactory(ModuleKeys.MODULE_MEOS);
        vm.expectRevert("Only BranchModuleManager");
        MeosFactory(meosFactory).deployModule(1, 1, address(0xabc));

        // IQR Factory deployment directly should fail
        address iqrFactory = mrProxy.getModuleFactory(ModuleKeys.MODULE_IQR);
        vm.expectRevert("Only BranchModuleManager");
        IqrFactory(iqrFactory).deployModule(1, 1, address(0xabc));

        // Loyalty Factory deployment directly should fail
        address loyaltyFactory = mrProxy.getModuleFactory(ModuleKeys.MODULE_LOYALTY);
        vm.expectRevert("Only BranchModuleManager");
        LoyaltyFactory(loyaltyFactory).deployModule(1, 1, address(0xabc));

        vm.stopPrank();
    }
}
