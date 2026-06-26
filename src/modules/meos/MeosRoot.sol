// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {PCManager} from "./PCManager.sol";
import {AccountManager} from "./AccountManager.sol";

/**
 * @title MeosRoot
 * @dev Hợp đồng chính (root) cho module MEOS. Đã tối ưu Storage.
 */
contract MeosRoot is Initializable {
    // --- Tối ưu Storage Packing (Gom vừa khít 1 Slot 256 bits) ---
    address public staffManager; // 160 bits
    uint48 public branchId; // 48 bits
    uint48 public orgId; // 48 bits

    // Các biến còn lại chiếm các slot riêng biệt
    address public pcManager;
    address public accountManager;
    address public branchModuleManager;

    function initialize(
        uint48 _branchId,
        uint48 _orgId,
        address _staffManager,
        address _pcManagerBeacon,
        address _accountManagerBeacon,
        address _branchModuleManager
    ) external initializer {
        staffManager = _staffManager;
        branchId = _branchId;
        orgId = _orgId;
        branchModuleManager = _branchModuleManager;

        // Deploy các contract con dưới dạng Beacon Proxy
        pcManager = address(
            new BeaconProxy(
                _pcManagerBeacon,
                abi.encodeCall(
                    PCManager.initialize,
                    (_branchId, _orgId, _branchModuleManager)
                )
            )
        );
        accountManager = address(
            new BeaconProxy(
                _accountManagerBeacon,
                abi.encodeCall(
                    AccountManager.initialize,
                    (_branchId, _orgId, _branchModuleManager)
                )
            )
        );
    }

    /**
     * @dev Trả về danh sách các contract con thuộc module MEOS.
     */
    function getSubContracts()
        external
        view
        returns (address _pcManager, address _accountManager)
    {
        return (pcManager, accountManager);
    }
}
