// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {SystemAccessControl} from "../src/core/SystemAccessControl.sol"; // Thay đổi đường dẫn nếu cần;
import {RoleHashes} from "../src/core/constants/RoleHashes.sol"; // Thay đổi đường dẫn nếu cần;

contract GrantRolesScript is Script {
    function run() public {
        // 1. Tải các biến từ file .env
        uint256 adminPrivateKey = vm.envUint("PRIVATE_KEY");
        address proxyAddress = vm.envAddress("PROXY_ADDRESS");
        address opsAdmin = vm.envAddress("OPS_ADMIN_ADDRESS");
        address platformAdmin = vm.envAddress("PLATFORM_ADMIN_ADDRESS");

        // 2. Trỏ interface/contract tới địa chỉ Proxy
        SystemAccessControl accessControl = SystemAccessControl(proxyAddress);

        // 3. Bắt đầu gửi transaction bằng private key của Admin
        vm.startBroadcast(adminPrivateKey);

        // 4. Thực thi gán quyền OPS_ADMIN_ROLE
        // Kiểm tra trước để tránh tốn gas nếu ví đã có quyền
        if (!accessControl.hasRole(RoleHashes.OPS_ADMIN_ROLE, opsAdmin)) {
            accessControl.grantRole(RoleHashes.OPS_ADMIN_ROLE, opsAdmin);
            console2.log("Granted OPS_ADMIN_ROLE to:", opsAdmin);
        } else {
            console2.log("Address already has OPS_ADMIN_ROLE:", opsAdmin);
        }

        // 5. Thực thi gán quyền PLATFORM_ADMIN_ROLE
        if (!accessControl.hasRole(RoleHashes.PLATFORM_ADMIN_ROLE, platformAdmin)) {
            accessControl.grantRole(RoleHashes.PLATFORM_ADMIN_ROLE, platformAdmin);
            console2.log("Granted PLATFORM_ADMIN_ROLE to:", platformAdmin);
        } else {
            console2.log("Address already has PLATFORM_ADMIN_ROLE:", platformAdmin);
        }

        // 6. Kết thúc broadcast
        vm.stopBroadcast();
    }
}
