// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseDomainLogic} from "../../shared/base/BaseDomainLogic.sol";
import {ModuleConstants} from "../../shared/constants/ModuleConstants.sol";

contract MeosLogicV1 is BaseDomainLogic {
    // Thêm biến state để test (ví dụ: đếm số phiên đã khởi tạo)
    mapping(uint256 => bool) public activeSessions;

    constructor(
        address _factory
    )
        BaseDomainLogic(
            _factory,
            ModuleConstants.MEOS,
            ModuleConstants.MEOS_CORE
        )
    {
        _disableInitializers();
    }

    function initialize() external initializer {
        // Khởi tạo...
    }

    function startSession(uint256 computerId) external onlyActiveModule {
        activeSessions[computerId] = true;
    }

    // --- HÀM CHO CASTE TEST ---
    function isComputerActive(uint256 computerId) external view returns (bool) {
        return activeSessions[computerId];
    }
}
