// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {SystemAccessControl} from "src/core/SystemAccessControl.sol";
import {ModuleManager} from "src/core/ModuleManager.sol";
import {OrganizationFactory} from "src/core/OrganizationFactory.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployCoreSystem is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerKey);

        // Lấy địa chỉ thật của deployer
        address deployerAddr = vm.addr(deployerKey);

        // 1. Deploy AccessControl (Proxy)
        SystemAccessControl accessControlImpl = new SystemAccessControl();
        ERC1967Proxy accessControlProxy = new ERC1967Proxy(
            address(accessControlImpl),
            abi.encodeWithSelector(
                SystemAccessControl.initialize.selector,
                deployerAddr
            )
        );
        SystemAccessControl accessControl = SystemAccessControl(address(accessControlProxy));

        // 2. Deploy ModuleManager (Proxy)
        ModuleManager mmImpl = new ModuleManager();
        ERC1967Proxy mmProxy = new ERC1967Proxy(
            address(mmImpl),
            abi.encodeWithSelector(
                ModuleManager.initialize.selector,
                address(accessControl)
            )
        );

        // 3. Deploy Factory (Proxy)
        OrganizationFactory factoryImpl = new OrganizationFactory();
        ERC1967Proxy factoryProxy = new ERC1967Proxy(
            address(factoryImpl),
            abi.encodeWithSelector(
                OrganizationFactory.initialize.selector,
                address(accessControl),
                address(mmProxy)
            )
        );

        vm.stopBroadcast();

        // 4. Lưu thông tin ra file JSON
        // Sử dụng chuỗi JSON object để serialize các địa chỉ
        string memory json = "deployment_info";
        vm.serializeAddress(json, "AccessControl", address(accessControl));
        vm.serializeAddress(json, "ModuleManager", address(mmProxy));
        string memory finalJson = vm.serializeAddress(
            json,
            "OrganizationFactory",
            address(factoryProxy)
        );

        // Đường dẫn đến thư mục deployments (đảm bảo thư mục này tồn tại)
        string memory path = string.concat(vm.projectRoot(), "/deployments/");
        vm.writeFile(string.concat(path, "core_system.json"), finalJson);

        console.log("--------------------------------------------------");
        console.log("AccessControl:", address(accessControl));
        console.log("ModuleManager Proxy:", address(mmProxy));
        console.log("OrganizationFactory Proxy:", address(factoryProxy));
        console.log("Deployment info saved to: deployments/core_system.json");
        console.log("--------------------------------------------------");
    }
}
