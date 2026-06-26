// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IModuleRegistry
 * @dev Interface cho ModuleRegistry — trung tâm đăng ký và quản lý module.
 */
interface IModuleRegistry {
    // ====== Events ======

    event ModuleRegistered(bytes32 indexed key, string name, address factory);
    event ModuleUpdated(bytes32 indexed key, address newFactory);
    event ModuleStatusChanged(bytes32 indexed key, bool active);
    event OrgModuleSubscribed(uint256 indexed orgId, bytes32 indexed moduleKey);
    event OrgModuleUnsubscribed(uint256 indexed orgId, bytes32 indexed moduleKey);

    // ====== Errors ======

    error ModuleAlreadyRegistered();
    error ModuleNotFound();
    error ModuleNotActive();
    error OrgAlreadySubscribed();
    error OrgNotSubscribed();
    error InvalidAddress();
    error Unauthorized();

    // ====== Admin Functions ======

    /**
     * @dev Đăng ký module mới vào hệ thống.
     */
    function registerModule(bytes32 key, string calldata name, address factory) external;

    /**
     * @dev Cập nhật factory address của module.
     */
    function updateModuleFactory(bytes32 key, address newFactory) external;

    /**
     * @dev Bật/tắt module trên toàn hệ thống.
     */
    function setModuleActive(bytes32 key, bool active) external;

    // ====== Subscription Functions ======

    /**
     * @dev Kích hoạt module cho Organization (khi org trả tiền).
     */
    function subscribeOrgToModule(uint256 orgId, bytes32 moduleKey) external;

    /**
     * @dev Huỷ đăng ký module cho Organization.
     */
    function unsubscribeOrgFromModule(uint256 orgId, bytes32 moduleKey) external;

    // ====== View Functions ======

    /**
     * @dev Kiểm tra org đã subscribe module chưa.
     */
    function isOrgSubscribed(uint256 orgId, bytes32 moduleKey) external view returns (bool);

    /**
     * @dev Lấy danh sách module keys mà org đã subscribe.
     */
    function getOrgModules(uint256 orgId) external view returns (bytes32[] memory);

    /**
     * @dev Lấy factory address của module.
     */
    function getModuleFactory(bytes32 key) external view returns (address);

    /**
     * @dev Kiểm tra module tồn tại và active.
     */
    function isModuleActive(bytes32 key) external view returns (bool);
}
