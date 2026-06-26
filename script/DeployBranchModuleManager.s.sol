// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {BranchModuleManager} from "../src/core/BranchModuleManager.sol";

contract DeployBranchModuleManager is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address accessControl = vm.envAddress("PROXY_ADDRESS");
        address organizationManager = vm.envAddress("ORGANIZATION_MANAGER_PROXY");
        address moduleRegistry = vm.envAddress("MODULE_REGISTRY_PROXY");
        address staffManagerBeacon = vm.envAddress("STAFF_MANAGER_BEACON");

        vm.startBroadcast(deployerPrivateKey);

        BranchModuleManager implementation = new BranchModuleManager();

        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            abi.encodeCall(
                BranchModuleManager.initialize, (accessControl, organizationManager, moduleRegistry, staffManagerBeacon)
            )
        );

        vm.stopBroadcast();

        console2.log("BranchModuleManager Implementation:", address(implementation));
        console2.log("BranchModuleManager Proxy:", address(proxy));

        string memory json = "deployments";
        vm.serializeAddress(json, "implementation", address(implementation));
        string memory finalJson = vm.serializeAddress(json, "proxy", address(proxy));

        vm.writeJson(finalJson, "deployments/branch_module_manager.json");
    }
}
