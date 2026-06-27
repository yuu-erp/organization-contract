// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import {SystemAccessControl} from "../src/core/SystemAccessControl.sol";
import {OrganizationManager} from "../src/core/OrganizationManager.sol";
import {OrganizationMetadataRegistry} from "../src/registry/OrganizationMetadataRegistry.sol";
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

import {OrganizationReader} from "../src/view/OrganizationReader.sol";

import {ModuleKeys} from "../src/core/constants/ModuleKeys.sol";
import {RoleHashes} from "../src/core/constants/RoleHashes.sol";

contract DeployFullSystem is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        address platformAdmin = vm.envAddress("PLATFORM_ADMIN_ADDRESS");
        address opsAdmin = vm.envAddress("OPS_ADMIN_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy SystemAccessControl (UUPS Proxy)
        address sacImpl = address(new SystemAccessControl());
        SystemAccessControl sacProxy = SystemAccessControl(
            address(
                new ERC1967Proxy(
                    sacImpl,
                    abi.encodeCall(SystemAccessControl.initialize, (deployer))
                )
            )
        );
        sacProxy.grantRole(RoleHashes.PLATFORM_ADMIN_ROLE, deployer);
        sacProxy.grantRole(RoleHashes.OPS_ADMIN_ROLE, deployer);

        // Cấp quyền thêm cho các địa chỉ từ file .env
        if (platformAdmin != address(0)) {
            sacProxy.grantRole(RoleHashes.PLATFORM_ADMIN_ROLE, platformAdmin);
        }
        if (opsAdmin != address(0)) {
            sacProxy.grantRole(RoleHashes.OPS_ADMIN_ROLE, opsAdmin);
        }

        // 2. Deploy OrganizationManager (UUPS Proxy)
        address omImpl = address(new OrganizationManager());
        OrganizationManager omProxy = OrganizationManager(
            address(
                new ERC1967Proxy(
                    omImpl,
                    abi.encodeCall(
                        OrganizationManager.initialize,
                        (address(sacProxy))
                    )
                )
            )
        );

        // 3. Deploy OrganizationMetadataRegistry (UUPS Proxy)
        address omrImpl = address(new OrganizationMetadataRegistry());
        OrganizationMetadataRegistry omrProxy = OrganizationMetadataRegistry(
            address(
                new ERC1967Proxy(
                    omrImpl,
                    abi.encodeCall(
                        OrganizationMetadataRegistry.initialize,
                        (address(sacProxy), address(omProxy))
                    )
                )
            )
        );

        // 4. Deploy ModuleRegistry (UUPS Proxy)
        address mrImpl = address(new ModuleRegistry());
        ModuleRegistry mrProxy = ModuleRegistry(
            address(
                new ERC1967Proxy(
                    mrImpl,
                    abi.encodeCall(
                        ModuleRegistry.initialize,
                        (address(sacProxy))
                    )
                )
            )
        );

        // 5. Deploy BranchStaffManager implementation + UpgradeableBeacon
        UpgradeableBeacon staffBeacon = new UpgradeableBeacon(address(new BranchStaffManager()), deployer);

        // 6. Deploy BranchModuleManager (UUPS Proxy)
        address bmmImpl = address(new BranchModuleManager());
        BranchModuleManager bmmProxy = BranchModuleManager(
            address(
                new ERC1967Proxy(
                    bmmImpl,
                    abi.encodeCall(
                        BranchModuleManager.initialize,
                        (address(sacProxy), address(omProxy), address(mrProxy), address(staffBeacon))
                    )
                )
            )
        );

        // Link OrganizationManager to ModuleRegistry and BranchModuleManager
        omProxy.setRegistryAndManager(address(mrProxy), address(bmmProxy));

        // 7. Deploy Module Beacons and Factories
        // MEOS
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

        // IQR
        {
            address posBeacon = address(new UpgradeableBeacon(address(new POSManager()), deployer));
            IqrFactory iqrFactory = new IqrFactory(
                address(new UpgradeableBeacon(address(new IqrRoot()), deployer)),
                posBeacon,
                address(bmmProxy)
            );
            mrProxy.registerModule(ModuleKeys.MODULE_IQR, "IQR", address(iqrFactory));
        }

        // LOYALTY
        {
            address pointBeacon = address(new UpgradeableBeacon(address(new PointManager()), deployer));
            LoyaltyFactory loyaltyFactory = new LoyaltyFactory(
                address(new UpgradeableBeacon(address(new LoyaltyRoot()), deployer)),
                pointBeacon,
                address(bmmProxy)
            );
            mrProxy.registerModule(ModuleKeys.MODULE_LOYALTY, "LOYALTY", address(loyaltyFactory));
        }

        // 8. Deploy OrganizationReader (Plain view contract)
        OrganizationReader reader = new OrganizationReader(
            address(omProxy),
            address(omrProxy),
            deployer
        );

        // Grant roles to contracts
        sacProxy.grantRole(RoleHashes.PLATFORM_ADMIN_ROLE, address(omProxy));
        sacProxy.grantRole(RoleHashes.PLATFORM_ADMIN_ROLE, address(omrProxy));
        sacProxy.grantRole(RoleHashes.PLATFORM_ADMIN_ROLE, address(mrProxy));
        sacProxy.grantRole(RoleHashes.PLATFORM_ADMIN_ROLE, address(bmmProxy));

        vm.stopBroadcast();

        // 9. Build nested JSON manually
        string memory output = string(
            abi.encodePacked(
                "{\n",
                "  \"SystemAccessControl\": {\n",
                "    \"impl\": \"", vm.toString(sacImpl), "\",\n",
                "    \"proxy\": \"", vm.toString(address(sacProxy)), "\"\n",
                "  },\n",
                "  \"OrganizationManager\": {\n",
                "    \"impl\": \"", vm.toString(omImpl), "\",\n",
                "    \"proxy\": \"", vm.toString(address(omProxy)), "\"\n",
                "  },\n",
                "  \"OrganizationMetadataRegistry\": {\n",
                "    \"impl\": \"", vm.toString(omrImpl), "\",\n",
                "    \"proxy\": \"", vm.toString(address(omrProxy)), "\"\n",
                "  },\n",
                "  \"ModuleRegistry\": {\n",
                "    \"impl\": \"", vm.toString(mrImpl), "\",\n",
                "    \"proxy\": \"", vm.toString(address(mrProxy)), "\"\n",
                "  },\n",
                "  \"BranchModuleManager\": {\n",
                "    \"impl\": \"", vm.toString(bmmImpl), "\",\n",
                "    \"proxy\": \"", vm.toString(address(bmmProxy)), "\"\n",
                "  },\n",
                "  \"OrganizationReader\": \"", vm.toString(address(reader)), "\"\n",
                "}"
            )
        );

        string memory path = "./deployments/system_deploy.json";
        vm.writeJson(output, path);

        console2.log("Deployment details saved to:", path);
    }
}
