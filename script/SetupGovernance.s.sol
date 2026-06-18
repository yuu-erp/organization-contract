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

        // 1. Đọc địa chỉ từ file
        string memory path = string.concat(
            vm.projectRoot(),
            "/deployments/core_system.json"
        );
        string memory json = vm.readFile(path);
        address mmAddress = vm.parseJsonAddress(json, ".ModuleManager");
        IModuleManager moduleManager = IModuleManager(mmAddress);

        vm.startBroadcast(deployerKey);

        // 2. Deploy EmptyLogic một lần duy nhất
        EmptyLogic emptyLogic = new EmptyLogic();

        // 3. Đăng ký các Module Cha
        bytes32 PARENT_SLOT = bytes32(0);

        _registerParent(
            moduleManager,
            ModuleConstants.MEOS,
            PARENT_SLOT,
            address(emptyLogic),
            deployerAddr
        );
        _registerParent(
            moduleManager,
            ModuleConstants.IQR,
            PARENT_SLOT,
            address(emptyLogic),
            deployerAddr
        );
        _registerParent(
            moduleManager,
            ModuleConstants.LOYALTY,
            PARENT_SLOT,
            address(emptyLogic),
            deployerAddr
        );

        vm.stopBroadcast();
    }

    function _registerParent(
        IModuleManager mm,
        bytes32 parentId,
        bytes32 subId,
        address logic,
        address ownerAddr
    ) internal {
        // Beacon trỏ vào EmptyLogic và Owner là ví deployer
        UpgradeableBeacon beacon = new UpgradeableBeacon(logic, ownerAddr);

        mm.registerSubModule(parentId, subId, address(beacon));

        console.log("Registered Parent Module:", uint256(parentId));
        console.log("Beacon Address:", address(beacon));
    }
}
