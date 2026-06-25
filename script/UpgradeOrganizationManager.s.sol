// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {OrganizationManager} from "../src/core/OrganizationManager.sol";

interface IOrganizationManagerProxy {
    function upgradeToAndCall(
        address newImplementation,
        bytes calldata data
    ) external;
}

contract UpgradeOrganizationManager is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address proxyAddress = vm.envAddress("ORGANIZATION_MANAGER_PROXY");

        vm.startBroadcast(deployerPrivateKey);

        OrganizationManager newImplementation = new OrganizationManager();

        IOrganizationManagerProxy(proxyAddress).upgradeToAndCall(
            address(newImplementation),
            ""
        );

        vm.stopBroadcast();

        console.log("New Implementation:", address(newImplementation));

        console.log("Proxy:", proxyAddress);
    }
}
