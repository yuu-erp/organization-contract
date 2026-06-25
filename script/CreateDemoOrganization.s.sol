// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";

import {OrganizationManager} from "../src/core/OrganizationManager.sol";

contract CreateDemoOrganization is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address organizationManagerAddress = vm.envAddress(
            "ORGANIZATION_MANAGER_PROXY"
        );

        address organizationOwner = vm.envAddress("ORGANIZATION_OWNER");

        vm.startBroadcast(deployerPrivateKey);

        OrganizationManager organizationManager = OrganizationManager(
            organizationManagerAddress
        );

        uint256 organizationId = organizationManager.createOrganization(
            organizationOwner
        );

        uint256 branchId1 = organizationManager.createBranch(organizationId);

        uint256 branchId2 = organizationManager.createBranch(organizationId);

        vm.stopBroadcast();

        string memory json = "demo";
        vm.serializeUint(json, "organizationId", organizationId);
        vm.serializeUint(json, "branchId1", branchId1);
        string memory finalJson = vm.serializeUint(
            json,
            "branchId2",
            branchId2
        );

        vm.writeJson(finalJson, "deployments/demo_organization.json");
    }
}
