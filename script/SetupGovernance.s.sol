// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {IModuleManager} from "src/core/interfaces/IModuleManager.sol";
import {ModuleConstants} from "src/shared/constants/ModuleConstants.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {EmptyLogic} from "src/infrastructure/EmptyLogic.sol";

contract SetupGovernance is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployerAddr = vm.addr(deployerKey);

        // 1. Đọc địa chỉ ModuleManager từ file core_system.json
        string memory corePath = string.concat(
            vm.projectRoot(),
            "/deployments/core_system.json"
        );
        address mmAddress = vm.parseJsonAddress(
            vm.readFile(corePath),
            ".ModuleManager"
        );
        IModuleManager moduleManager = IModuleManager(mmAddress);

        vm.startBroadcast(deployerKey);

        // 2. Deploy EmptyLogic một lần duy nhất
        EmptyLogic emptyLogic = new EmptyLogic();
        bytes32 PARENT_SLOT = bytes32(0);

        // 3. Đăng ký các Module và lấy địa chỉ Beacon
        address beaconMeos = _registerParent(
            moduleManager,
            ModuleConstants.MEOS,
            PARENT_SLOT,
            address(emptyLogic),
            deployerAddr
        );
        address beaconIqr = _registerParent(
            moduleManager,
            ModuleConstants.IQR,
            PARENT_SLOT,
            address(emptyLogic),
            deployerAddr
        );
        address beaconLoyalty = _registerParent(
            moduleManager,
            ModuleConstants.LOYALTY,
            PARENT_SLOT,
            address(emptyLogic),
            deployerAddr
        );

        // 4. Lưu vào file registry.json với cấu trúc chuẩn
        // "registry" là root key, các cặp tiếp theo là key-value trong object đó
        string memory json = vm.serializeAddress(
            "registry",
            "MEOS",
            beaconMeos
        );
        json = vm.serializeAddress("registry", "IQR", beaconIqr);
        json = vm.serializeAddress("registry", "LOYALTY", beaconLoyalty);

        vm.writeJson(json, "./deployments/registry.json");

        vm.stopBroadcast();
        console.log("Registry saved to deployments/registry.json");
    }

    function _registerParent(
        IModuleManager mm,
        bytes32 parentId,
        bytes32 subId,
        address logic,
        address ownerAddr
    ) internal returns (address) {
        // Beacon trỏ vào logic và Owner là ví deployer
        UpgradeableBeacon beacon = new UpgradeableBeacon(logic, ownerAddr);

        mm.registerSubModule(parentId, subId, address(beacon));

        console.log("Registered Parent Module:", uint256(parentId));
        console.log("Beacon Address:", address(beacon));

        return address(beacon);
    }
}
