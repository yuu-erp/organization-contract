// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";

import {OrganizationManager} from "../src/core/OrganizationManager.sol";
import {IBranchModuleManager} from "../src/core/interfaces/IBranchModuleManager.sol";
import {ModuleKeys} from "../src/core/constants/ModuleKeys.sol";

contract CreateDemoOrganization is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address organizationManagerAddress = vm.envAddress("ORGANIZATION_MANAGER_PROXY");

        address organizationOwner = vm.envAddress("ORGANIZATION_OWNER");

        vm.startBroadcast(deployerPrivateKey);

        OrganizationManager organizationManager = OrganizationManager(organizationManagerAddress);

        // 1. Đăng ký module MEOS và LOYALTY cho Organization
        bytes32[] memory orgModules = new bytes32[](2);
        orgModules[0] = ModuleKeys.MODULE_MEOS;
        orgModules[1] = ModuleKeys.MODULE_LOYALTY;

        uint256 organizationId = organizationManager.createOrganization(organizationOwner, orgModules);

        // 2. Tạo Branch 1 bật cả MEOS và LOYALTY
        bytes32[] memory branch1Modules = new bytes32[](2);
        branch1Modules[0] = ModuleKeys.MODULE_MEOS;
        branch1Modules[1] = ModuleKeys.MODULE_LOYALTY;
        uint256 branchId1 = organizationManager.createBranch(organizationId, branch1Modules);

        // 3. Tạo Branch 2 chỉ bật LOYALTY
        bytes32[] memory branch2Modules = new bytes32[](1);
        branch2Modules[0] = ModuleKeys.MODULE_LOYALTY;
        uint256 branchId2 = organizationManager.createBranch(organizationId, branch2Modules);

        vm.stopBroadcast();

        // 4. Lấy địa chỉ proxy của từng branch cho từng modules
        address branchModuleManagerAddress = organizationManager.branchModuleManager();
        IBranchModuleManager branchModuleManager = IBranchModuleManager(branchModuleManagerAddress);

        address branch1MeosProxy = branchModuleManager.getModuleRoot(branchId1, ModuleKeys.MODULE_MEOS);
        address branch1LoyaltyProxy = branchModuleManager.getModuleRoot(branchId1, ModuleKeys.MODULE_LOYALTY);
        address branch2LoyaltyProxy = branchModuleManager.getModuleRoot(branchId2, ModuleKeys.MODULE_LOYALTY);

        // 5. Ghi kết quả vào file JSON
        string memory json = "demo";
        vm.serializeUint(json, "organizationId", organizationId);
        vm.serializeUint(json, "branchId1", branchId1);
        vm.serializeAddress(json, "branch1_MEOS_proxy", branch1MeosProxy);
        vm.serializeAddress(json, "branch1_LOYALTY_proxy", branch1LoyaltyProxy);
        vm.serializeUint(json, "branchId2", branchId2);
        string memory finalJson = vm.serializeAddress(json, "branch2_LOYALTY_proxy", branch2LoyaltyProxy);

        vm.writeJson(finalJson, "deployments/demo_organization.json");
    }
}
