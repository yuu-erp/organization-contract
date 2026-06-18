// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IOrganizationFactory} from "../../core/interfaces/IOrganizationFactory.sol";
import {ModuleConstants} from "../../shared/constants/ModuleConstants.sol";

// Interface để đọc nhanh thông tin immutable từ vỏ bọc Proxy
interface IBranchProxy {
    function BRANCH_ID() external view returns (uint256);
}

contract IqrLogicV1 {
    // Địa chỉ của Factory hệ thống
    IOrganizationFactory public immutable factory;
    bytes32 public immutable parentId;
    bytes32 public immutable subId;

    constructor(address _factory) {
        factory = IOrganizationFactory(_factory);
        parentId = ModuleConstants.IQR;
        subId = ModuleConstants.IQR_CORE;
    }

    // TẤM KHIÊN BẢO VỆ: Chặn đứng client khi module bị tắt
    modifier onlyActiveModule() {
        // 1. Tự đọc BRANCH_ID của chính mình từ lớp vỏ Proxy
        uint256 branchId = IBranchProxy(address(this)).BRANCH_ID();

        // 2. Hỏi Factory xem cặp [branchId][IQR][CORE] hiện tại có đang hoạt động không
        address activeProxy = factory.branchModules(branchId, parentId, subId);

        // Nếu Factory đã xóa mapping hoặc đánh dấu tắt (trả về address(0))
        if (activeProxy == address(0)) {
            revert(unicode"Hethong: Module da bi khoa hoặc chua kich hoat!");
        }
        _;
    }

    // Các hàm nghiệp vụ của tiệm net luôn phải có tấm khiên bảo vệ
    function createFoodOrder(
        string calldata foodName
    ) external onlyActiveModule {
        // Logic tạo đơn gọi món chỉ chạy nếu đã đóng tiền và module đang bật
    }
}
