// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IOrganizationFactory} from "../../core/interfaces/IOrganizationFactory.sol";

/**
 * @title IBranchProxy
 * @dev Interface bổ trợ dùng để đọc nhanh dữ liệu đóng băng (immutable) từ lớp vỏ Proxy.
 */
interface IBranchProxy {
    function BRANCH_ID() external view returns (uint256);

    function ORG_ID() external view returns (uint256);
}

/**
 * @title BaseDomainLogic
 * @dev Lớp nền tảng toàn cục thiết lập cơ chế bảo mật (Circuit Breaker) và định tuyến chéo cho mọi module.
 */
abstract contract BaseDomainLogic is Initializable {
    IOrganizationFactory public immutable factory;
    bytes32 public immutable parentId;
    bytes32 public immutable subId;

    /**
     * @dev Constructor lưu tọa độ Factory hệ thống và mã băm định danh của từng module.
     */
    constructor(address _factory, bytes32 _parentId, bytes32 _subId) {
        factory = IOrganizationFactory(_factory);
        parentId = _parentId;
        subId = _subId;
    }

    /**
     * @dev TẤM KHIÊN BẢO VỆ: Chặn đứng client gọi trực tiếp vào Proxy nếu module tại chi nhánh đó đã bị tắt.
     */
    modifier onlyActiveModule() {
        // Tự đọc BRANCH_ID của chính mình từ lớp vỏ Proxy
        uint256 myBranchId = IBranchProxy(address(this)).BRANCH_ID();

        // Kiểm tra xem Factory hệ thống có đang ghi nhận Proxy này hoạt động không
        address activeProxy = factory.branchModules(myBranchId, parentId, subId);

        require(
            activeProxy != address(0),
            "System: Module is disabled or not enabled for this branch"
        );
        require(
            activeProxy == address(this),
            "System: Invalid proxy caller context"
        );
        _;
    }

    /**
     * @dev HỆ THỐNG PHÂN GIẢI ĐỊA CHỈ (DNS nội bộ): Giúp các sub-contract cùng chi nhánh tìm thấy nhau.
     */
    function _getSiblingProxy(
        bytes32 siblingParentId,
        bytes32 siblingSubId
    ) internal view returns (address) {
        uint256 myBranchId = IBranchProxy(address(this)).BRANCH_ID();

        address sibling = factory.branchModules(myBranchId, siblingParentId, siblingSubId);
        require(
            sibling != address(0),
            "System: Sibling module is not deployed for this branch"
        );
        return sibling;
    }
}
