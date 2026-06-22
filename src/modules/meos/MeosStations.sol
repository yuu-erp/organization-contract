// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseDomainLogic} from "../../shared/base/BaseDomainLogic.sol";
import {ModuleConstants} from "../../shared/constants/ModuleConstants.sol";

contract MeosStations is BaseDomainLogic {
    constructor(
        address _factory
    )
        BaseDomainLogic(
            _factory,
            ModuleConstants.MEOS,
            ModuleConstants.MEOS_STATIONS
        )
    {
        _disableInitializers();
    }

    function initialize() external initializer {
        // Khởi tạo logic MEOS_STATIONS tại đây
    }
}
