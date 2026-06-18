// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseDomainLogic} from "../../shared/base/BaseDomainLogic.sol";
import {ModuleConstants} from "../../shared/constants/ModuleConstants.sol";

contract IqrMenuLogic is BaseDomainLogic {
    struct MenuItem {
        string name;
        uint256 price;
        uint256 stock;
    }

    mapping(uint256 => MenuItem) public menu;
    uint256 public nextItemId;

    // Truyền địa chỉ Factory và mã băm "IQR_MENU" cho contract cha
    constructor(
        address _factory
    ) BaseDomainLogic(_factory, ModuleConstants.IQR, ModuleConstants.IQR_MENU) {
        _disableInitializers();
    }

    function initialize() external initializer {
        nextItemId = 1;
    }

    // Tiệm net thêm nước ngọt, mì tôm vào menu
    function addMenuItem(
        string calldata name,
        uint256 price,
        uint256 stock
    ) external onlyActiveModule {
        menu[nextItemId++] = MenuItem(name, price, stock);
    }

    // API nội bộ cho các Sub-module khác gọi (VD: IQR_ORDER)
    function reduceStock(
        uint256 itemId,
        uint256 qty
    ) external onlyActiveModule {
        require(menu[itemId].stock >= qty, "IQR: Het hang!");
        menu[itemId].stock -= qty;
    }

    function getPrice(uint256 itemId) external view returns (uint256) {
        return menu[itemId].price;
    }
}
