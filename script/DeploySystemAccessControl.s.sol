// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {SystemAccessControl} from "../src/core/SystemAccessControl.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeploySystemAccessControl is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address defaultAdmin = vm.envAddress("DEFAULT_ADMIN");

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy Implementation
        SystemAccessControl implementation = new SystemAccessControl();
        console2.log("SystemAccessControl Implementation deployed at:", address(implementation));

        // 2. Encode Initialization Data
        bytes memory initData = abi.encodeCall(SystemAccessControl.initialize, (defaultAdmin));

        // 3. Deploy Proxy and Initialize
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        console2.log("SystemAccessControl Proxy deployed at:", address(proxy));

        vm.stopBroadcast();

        // 4. Save to JSON
        string memory obj = "deployData";
        vm.serializeAddress(obj, "implementation", address(implementation));
        string memory finalJson = vm.serializeAddress(obj, "proxy", address(proxy));

        // Tạo thư mục nếu chưa có bằng cách ghi thẳng vào file (Foundry tự tạo file nếu thiếu)
        vm.writeJson(finalJson, "deployments/SystemAccessControl.json");
    }
}
