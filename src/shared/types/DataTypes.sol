// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title DataTypes
 * @dev Định nghĩa các cấu trúc dữ liệu toàn cục (Global Structs) dùng chung.
 */

struct Organization {
    uint256 id;
    address walletAddress; // Ví người sở hữu tối cao của tổ chức
    string code; // Định danh duy nhất (VD: "cyberking")
    string storeName; // Tên hiển thị (VD: "CyberKing Net Cafe")
    string phone; // Số điện thoại liên hệ
    string storeAddress; // Địa chỉ trụ sở chính
    bool isActive; // Trạng thái hoạt động (bật/tắt toàn bộ tổ chức)
}

struct Branch {
    uint256 id;
    uint256 orgId;
    string name;
    bool isActive;
}

struct ModuleConfig {
    address beacon;
    bool isRegistered;
}

// Struct phục vụ riêng cho việc render UI của Frontend
struct BranchUIState {
    uint256 branchId;
    string name;
    bool isActive;
    bool[] moduleStatuses; // Mảng trạng thái: [true, false] tương ứng với [IQR, MEOS]
}
