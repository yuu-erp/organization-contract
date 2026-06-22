// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {MeosStations} from "src/modules/meos/MeosStations.sol";
import {IModuleManager} from "src/core/interfaces/IModuleManager.sol";
import {ModuleConstants} from "src/shared/constants/ModuleConstants.sol";

contract DeployMeosStations is Script {
    using stdJson for string;

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");

        // 1. Đọc địa chỉ Factory và ModuleManager từ core_system.json
        string memory corePath = string.concat(
            vm.projectRoot(),
            "/deployments/core_system.json"
        );
        string memory coreJson = vm.readFile(corePath);
        address factoryAddress = coreJson.readAddress(".OrganizationFactory");
        address mmAddress = coreJson.readAddress(".ModuleManager");

        vm.startBroadcast(deployerKey);

        // 2. Deploy Logic Contract (Truyền Factory address vào constructor)
        MeosStations stationsLogic = new MeosStations(factoryAddress);
        console.log("1. Deployed MeosStations Logic at:", address(stationsLogic));

        // 3. Deploy UpgradeableBeacon trỏ về Logic (Chủ sở hữu của beacon là deployer trước)
        // Lưu ý: Tùy thuộc vào thiết kế, bạn có thể muốn transferOwnership của Beacon sang ModuleManager hoặc MultiSig
        UpgradeableBeacon beacon = new UpgradeableBeacon(address(stationsLogic), vm.addr(deployerKey));
        console.log("2. Deployed UpgradeableBeacon at:", address(beacon));

        // 4. Đăng ký Beacon vào ModuleManager
        IModuleManager mm = IModuleManager(mmAddress);
        mm.registerSubModule(ModuleConstants.MEOS, ModuleConstants.MEOS_STATIONS, address(beacon));
        console.log("3. Registered MEOS_STATIONS to ModuleManager successfully.");

        vm.stopBroadcast();

        // 5. Lưu Beacon address vào file (bạn có thể gộp vào registry.json tuỳ ý)
        string memory json = "stations_registry";
        string memory finalJson = vm.serializeAddress(json, "MEOS_STATIONS", address(beacon));
        string memory path = string.concat(vm.projectRoot(), "/deployments/");
        vm.writeFile(string.concat(path, "meos_stations_registry.json"), finalJson);
        
        console.log("Saved Beacon address to deployments/meos_stations_registry.json");
    }
}
