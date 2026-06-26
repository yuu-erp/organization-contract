// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {OrganizationManager} from "../src/core/OrganizationManager.sol";

contract DeployOrganizationManager is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address accessControl = vm.envAddress("PROXY_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        OrganizationManager implementation = new OrganizationManager();

        ERC1967Proxy proxy =
            new ERC1967Proxy(address(implementation), abi.encodeCall(OrganizationManager.initialize, (accessControl)));

        vm.stopBroadcast();

        console2.log("OrganizationManager Implementation:", address(implementation));

        console2.log("OrganizationManager Proxy:", address(proxy));

        string memory json = "deployments";
        vm.serializeAddress(json, "implementation", address(implementation));
        string memory finalJson = vm.serializeAddress(json, "proxy", address(proxy));

        vm.writeJson(finalJson, "deployments/organization_manager.json");
    }
}
