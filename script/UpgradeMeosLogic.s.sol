// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {MeosLogicV1} from "src/modules/meos/MeosLogicV1.sol";

contract UpgradeMeosLogic is Script {
    using stdJson for string;

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");

        // 1. Đọc địa chỉ Beacon từ registry.json (Dạng phẳng)
        string memory regPath = string.concat(
            vm.projectRoot(),
            "/deployments/registry.json"
        );
        string memory regJson = vm.readFile(regPath);
        // Đã sửa: bỏ ".registry" vì file của bạn không lồng object
        address beaconAddress = regJson.readAddress(".MEOS");

        // 2. Đọc địa chỉ Factory từ core_system.json
        string memory corePath = string.concat(
            vm.projectRoot(),
            "/deployments/core_system.json"
        );
        string memory coreJson = vm.readFile(corePath);
        address factoryAddress = coreJson.readAddress(".OrganizationFactory");

        vm.startBroadcast(deployerKey);

        // 3. Deploy Logic V1
        MeosLogicV1 newLogic = new MeosLogicV1(factoryAddress);
        console.log("Deployed new MeosLogicV1 at:", address(newLogic));

        // 4. Nâng cấp Beacon
        UpgradeableBeacon beacon = UpgradeableBeacon(beaconAddress);
        beacon.upgradeTo(address(newLogic));

        console.log("Beacon upgraded to new logic successfully!");

        vm.stopBroadcast();
    }
}
