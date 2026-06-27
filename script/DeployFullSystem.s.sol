// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {SystemAccessControl} from "../src/core/SystemAccessControl.sol";
import {OrganizationManager} from "../src/core/OrganizationManager.sol";
import {OrganizationMetadataRegistry} from "../src/registry/OrganizationMetadataRegistry.sol";
import {OrganizationReader} from "../src/view/OrganizationReader.sol";

import {RoleHashes} from "../src/core/constants/RoleHashes.sol";

contract DeployFullSystem is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

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

        // 4. Deploy OrganizationReader (Plain view contract)
        OrganizationReader reader = new OrganizationReader(
            address(omProxy),
            address(omrProxy),
            deployer
        );

        // Grant roles to contracts
        sacProxy.grantRole(RoleHashes.PLATFORM_ADMIN_ROLE, address(omProxy));
        sacProxy.grantRole(RoleHashes.PLATFORM_ADMIN_ROLE, address(omrProxy));

        vm.stopBroadcast();

        // 5. Build nested JSON manually
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
                "  \"OrganizationReader\": \"", vm.toString(address(reader)), "\"\n",
                "}"
            )
        );

        string memory path = "./deployments/system_deploy.json";
        vm.writeJson(output, path);

        console2.log("Deployment details saved to:", path);
    }
}
