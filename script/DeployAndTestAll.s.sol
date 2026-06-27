// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import {SystemAccessControl} from "../src/core/SystemAccessControl.sol";
import {OrganizationManager} from "../src/core/OrganizationManager.sol";
import {ModuleRegistry} from "../src/registry/ModuleRegistry.sol";
import {BranchModuleManager} from "../src/core/BranchModuleManager.sol";
import {BranchStaffManager} from "../src/core/BranchStaffManager.sol";

import {MeosRoot} from "../src/modules/meos/MeosRoot.sol";
import {PCManager} from "../src/modules/meos/PCManager.sol";
import {AccountManager} from "../src/modules/meos/AccountManager.sol";
import {MeosFactory} from "../src/modules/meos/MeosFactory.sol";
import {IqrRoot} from "../src/modules/iqr/IqrRoot.sol";
import {IqrFactory} from "../src/modules/iqr/IqrFactory.sol";
import {LoyaltyRoot} from "../src/modules/loyalty/LoyaltyRoot.sol";
import {LoyaltyFactory} from "../src/modules/loyalty/LoyaltyFactory.sol";
import {POSManager} from "../src/modules/iqr/POSManager.sol";
import {PointManager} from "../src/modules/loyalty/PointManager.sol";

import {ModuleKeys} from "../src/core/constants/ModuleKeys.sol";
import {RoleHashes} from "../src/core/constants/RoleHashes.sol";

contract DeployAndTestAll is Script {
    struct System {
        address sac;
        address om;
        address mr;
        address bmm;
    }

    struct TestResults {
        uint48 orgId;
        uint48 branchId1;
        address branch1Meos;
        address branch1Iqr;
        address branch1Loyalty;
        address branch1MeosPCManager;
        address branch1MeosAccountManager;
        uint48 branchId2;
        address branch2Meos;
        address branch2Iqr;
        address branch2Loyalty;
        address branch2MeosPCManager;
        address branch2MeosAccountManager;
    }

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        System memory sys = deploySystem(deployer);

        testScenario(sys);

        vm.stopBroadcast();
    }

    function deploySystem(address deployer) internal returns (System memory sys) {
        // 1. Deploy SystemAccessControl (UUPS Proxy)
        SystemAccessControl sacProxy = SystemAccessControl(
            address(
                new ERC1967Proxy(
                    address(new SystemAccessControl()), abi.encodeCall(SystemAccessControl.initialize, (deployer))
                )
            )
        );
        sacProxy.grantRole(RoleHashes.PLATFORM_ADMIN_ROLE, deployer);
        sacProxy.grantRole(RoleHashes.OPS_ADMIN_ROLE, deployer);

        // 2. Deploy OrganizationManager (UUPS Proxy)
        OrganizationManager omProxy = OrganizationManager(
            address(
                new ERC1967Proxy(
                    address(new OrganizationManager()),
                    abi.encodeCall(OrganizationManager.initialize, (address(sacProxy)))
                )
            )
        );

        // 3. Deploy ModuleRegistry (UUPS Proxy)
        ModuleRegistry mrProxy = ModuleRegistry(
            address(
                new ERC1967Proxy(
                    address(new ModuleRegistry()), abi.encodeCall(ModuleRegistry.initialize, (address(sacProxy)))
                )
            )
        );

        // 4. Deploy BranchStaffManager implementation + UpgradeableBeacon
        UpgradeableBeacon staffBeacon = new UpgradeableBeacon(address(new BranchStaffManager()), deployer);

        // 5. Deploy BranchModuleManager (UUPS Proxy)
        BranchModuleManager bmmProxy = BranchModuleManager(
            address(
                new ERC1967Proxy(
                    address(new BranchModuleManager()),
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
        {
            address pcBeacon = address(new UpgradeableBeacon(address(new PCManager()), deployer));
            address accBeacon = address(new UpgradeableBeacon(address(new AccountManager()), deployer));
            MeosFactory meosFactory = new MeosFactory(
                address(new UpgradeableBeacon(address(new MeosRoot()), deployer)),
                pcBeacon,
                accBeacon,
                address(bmmProxy)
            );
            mrProxy.registerModule(ModuleKeys.MODULE_MEOS, "MEOS", address(meosFactory));
        }

        {
            address posBeacon = address(new UpgradeableBeacon(address(new POSManager()), deployer));
            IqrFactory iqrFactory = new IqrFactory(
                address(new UpgradeableBeacon(address(new IqrRoot()), deployer)),
                posBeacon,
                address(bmmProxy)
            );
            mrProxy.registerModule(ModuleKeys.MODULE_IQR, "IQR", address(iqrFactory));
        }

        {
            address pointBeacon = address(new UpgradeableBeacon(address(new PointManager()), deployer));
            LoyaltyFactory loyaltyFactory = new LoyaltyFactory(
                address(new UpgradeableBeacon(address(new LoyaltyRoot()), deployer)),
                pointBeacon,
                address(bmmProxy)
            );
            mrProxy.registerModule(ModuleKeys.MODULE_LOYALTY, "LOYALTY", address(loyaltyFactory));
        }

        sys.sac = address(sacProxy);
        sys.om = address(omProxy);
        sys.mr = address(mrProxy);
        sys.bmm = address(bmmProxy);
    }

    function testScenario(System memory sys) internal {
        OrganizationManager omProxy = OrganizationManager(sys.om);
        BranchModuleManager bmmProxy = BranchModuleManager(sys.bmm);

        TestResults memory res;

        // Tạo 1 Organization với full 3 modules
        bytes32[] memory orgModules = new bytes32[](3);
        orgModules[0] = ModuleKeys.MODULE_MEOS;
        orgModules[1] = ModuleKeys.MODULE_IQR;
        orgModules[2] = ModuleKeys.MODULE_LOYALTY;

        res.orgId = omProxy.createOrganization(address(0xDEAdbeef), orgModules);

        // Branch 1: Bật FULL 3 modules
        bytes32[] memory branch1Modules = new bytes32[](3);
        branch1Modules[0] = ModuleKeys.MODULE_MEOS;
        branch1Modules[1] = ModuleKeys.MODULE_IQR;
        branch1Modules[2] = ModuleKeys.MODULE_LOYALTY;
        res.branchId1 = omProxy.createBranch(res.orgId, branch1Modules);

        // Branch 2: Bật MEOS và LOYALTY (Không bật IQR)
        bytes32[] memory branch2Modules = new bytes32[](2);
        branch2Modules[0] = ModuleKeys.MODULE_MEOS;
        branch2Modules[1] = ModuleKeys.MODULE_LOYALTY;
        res.branchId2 = omProxy.createBranch(res.orgId, branch2Modules);

        // Query addresses
        res.branch1Meos = bmmProxy.getModuleRoot(res.branchId1, ModuleKeys.MODULE_MEOS);
        res.branch1Iqr = bmmProxy.getModuleRoot(res.branchId1, ModuleKeys.MODULE_IQR);
        res.branch1Loyalty = bmmProxy.getModuleRoot(res.branchId1, ModuleKeys.MODULE_LOYALTY);

        if (res.branch1Meos != address(0)) {
            res.branch1MeosPCManager = MeosRoot(res.branch1Meos).pcManager();
            res.branch1MeosAccountManager = MeosRoot(res.branch1Meos).accountManager();
        }

        res.branch2Meos = bmmProxy.getModuleRoot(res.branchId2, ModuleKeys.MODULE_MEOS);
        res.branch2Iqr = bmmProxy.getModuleRoot(res.branchId2, ModuleKeys.MODULE_IQR);
        res.branch2Loyalty = bmmProxy.getModuleRoot(res.branchId2, ModuleKeys.MODULE_LOYALTY);

        if (res.branch2Meos != address(0)) {
            res.branch2MeosPCManager = MeosRoot(res.branch2Meos).pcManager();
            res.branch2MeosAccountManager = MeosRoot(res.branch2Meos).accountManager();
        }

        console2.log("Deployment and Test successful!");
        console2.log("Organization ID:", res.orgId);
        console2.log("Branch 1 ID:", res.branchId1);
        console2.log("  - MEOS Proxy:", res.branch1Meos);
        console2.log("  - IQR Proxy:", res.branch1Iqr);
        console2.log("  - LOYALTY Proxy:", res.branch1Loyalty);
        console2.log("Branch 2 ID:", res.branchId2);
        console2.log("  - MEOS Proxy:", res.branch2Meos);
        console2.log("  - IQR Proxy (Should be 0x0):", res.branch2Iqr);
        console2.log("  - LOYALTY Proxy:", res.branch2Loyalty);

        saveJson(sys, res);
    }

    function saveJson(System memory sys, TestResults memory res) internal {
        string memory sysFinal;
        {
            string memory sysJson = "sys_key";
            vm.serializeAddress(sysJson, "system_access_control", sys.sac);
            vm.serializeAddress(sysJson, "organization_manager", sys.om);
            vm.serializeAddress(sysJson, "module_registry", sys.mr);
            sysFinal = vm.serializeAddress(sysJson, "branch_module_manager", sys.bmm);
        }

        string memory b1Final;
        {
            string memory b1MeosFinal;
            {
                string memory b1MeosJson = "b1_meos_key";
                vm.serializeAddress(b1MeosJson, "root", res.branch1Meos);
                vm.serializeAddress(b1MeosJson, "PCManager", res.branch1MeosPCManager);
                b1MeosFinal = vm.serializeAddress(b1MeosJson, "AccountManager", res.branch1MeosAccountManager);
            }

            string memory b1ModFinal;
            {
                string memory b1ModJson = "b1_mod_key";
                vm.serializeString(b1ModJson, "MEOS", b1MeosFinal);
                vm.serializeAddress(b1ModJson, "IQR", res.branch1Iqr);
                b1ModFinal = vm.serializeAddress(b1ModJson, "LOYALTY", res.branch1Loyalty);
            }

            string memory b1Json = "b1_key";
            vm.serializeUint(b1Json, "id", res.branchId1);
            vm.serializeString(b1Json, "name", "Branch 1 (Full Modules)");
            b1Final = vm.serializeString(b1Json, "modules", b1ModFinal);
        }

        string memory b2Final;
        {
            string memory b2MeosFinal;
            {
                string memory b2MeosJson = "b2_meos_key";
                vm.serializeAddress(b2MeosJson, "root", res.branch2Meos);
                vm.serializeAddress(b2MeosJson, "PCManager", res.branch2MeosPCManager);
                b2MeosFinal = vm.serializeAddress(b2MeosJson, "AccountManager", res.branch2MeosAccountManager);
            }

            string memory b2ModFinal;
            {
                string memory b2ModJson = "b2_mod_key";
                vm.serializeString(b2ModJson, "MEOS", b2MeosFinal);
                vm.serializeAddress(b2ModJson, "IQR", res.branch2Iqr);
                b2ModFinal = vm.serializeAddress(b2ModJson, "LOYALTY", res.branch2Loyalty);
            }

            string memory b2Json = "b2_key";
            vm.serializeUint(b2Json, "id", res.branchId2);
            vm.serializeString(b2Json, "name", "Branch 2 (MEOS + LOYALTY)");
            b2Final = vm.serializeString(b2Json, "modules", b2ModFinal);
        }

        // Build the raw JSON string manually to prevent double-escaping
        string memory finalJson = string.concat(
            "{\n",
            "  \"system_contracts\": ",
            sysFinal,
            ",\n",
            "  \"organization\": {\n",
            "    \"id\": ",
            vm.toString(res.orgId),
            ",\n",
            "    \"branches\": [\n",
            "      ",
            b1Final,
            ",\n",
            "      ",
            b2Final,
            "\n",
            "    ]\n",
            "  }\n",
            "}"
        );

        vm.writeFile("deployments/demo_organization.json", finalJson);
    }
}
