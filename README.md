Tuyệt vời. Với thông tin mới này mình đã hiểu khoảng **80–90% kiến trúc bạn đang xây** và có thể bắt đầu thiết kế roadmap thay vì chỉ review code.

## Hiện tại mình hiểu kiến trúc như sau

```text
SystemAccessControl
        │
        ▼
OrganizationManager
        │
        ├── Organization A
        │      ├── sở hữu Module MEOS
        │      ├── sở hữu Module IQR
        │      └── sở hữu Module CRM
        │
        └── Branch 1
               ├── bật MEOS
               └── bật IQR

        └── Branch 2
               ├── bật MEOS
               └── bật CRM
```

Khi tạo Branch:

```text
Create Branch
    ↓
Check modules branch muốn bật
    ↓
Check Organization có sở hữu modules đó không
    ↓
Deploy Module Bundle tương ứng
```

Ví dụ:

```text
Branch A
    ├── MEOS Bundle
    │      ├── PCManager
    │      ├── ZoneManager
    │      ├── PlayTimeManager
    │      └── BillingManager
    │
    └── IQR Bundle
           ├── Inventory
           └── POS
```

Mỗi branch sẽ có bộ contract riêng.

---

# Mình thấy một điểm rất quan trọng

Hiện tại Factory của bạn đang trả về:

```solidity
function deployModuleForBranch(
    uint256 branchId
)
```

=> return một địa chỉ.

Nhưng requirement thực tế của bạn là:

```text
1 Module
=
1 Bundle
=
Nhiều contract
```

Ví dụ:

```text
MEOS
 ├─ PCManager
 ├─ ZoneManager
 ├─ BillingManager
 └─ PlayTimeManager
```

Lúc này:

```solidity
mapping(uint256 => mapping(bytes32 => address))
public branchModuleProxies;
```

sẽ không còn đủ nữa.

---

# Kiến trúc mình khuyến nghị

## Module Root Pattern

Thay vì:

```text
Branch
   └── MEOS -> Address
```

nên là:

```text
Branch
   └── MEOSRoot
          ├── PCManager
          ├── ZoneManager
          ├── BillingManager
          └── PlayTimeManager
```

Factory deploy:

```solidity
MeosRoot
PCManager
ZoneManager
BillingManager
PlayTimeManager
```

sau đó trả về:

```solidity
return address(meosRoot);
```

OrganizationManager chỉ cần lưu:

```solidity
branchModuleRoots[branchId][MODULE_MEOS]
```

---

# Module Root nên chứa gì

Ví dụ:

```solidity
contract MeosRoot {
    address public pcManager;
    address public zoneManager;
    address public billingManager;
    address public playTimeManager;
}
```

Khi frontend cần:

```text
getMeosContracts(branchId)
```

trả về:

```json
{
  "root": "...",
  "pcManager": "...",
  "zoneManager": "...",
  "billingManager": "...",
  "playTimeManager": "..."
}
```

---

# Hiện tại mình thấy bạn đang thiếu 1 tầng

Hiện tại:

```text
OrganizationManager
    ↓
Factory
    ↓
Logic
```

Mình nghĩ nên là:

```text
OrganizationManager
    ↓
Module Factory
    ↓
Module Root
    ↓
Sub Contracts
```

---

# Phần quyền hiện tại có vấn đề

Trong `MeosLogic`

```solidity
modifier onlyOrgOwner()
```

đang check:

```solidity
msg.sender == ORG_WALLET
```

Điều này ổn với:

```text
Owner
```

nhưng không ổn với:

```text
Manager Chi Nhánh
Nhân viên
Thu ngân
Kỹ thuật viên
```

sau này.

---

# Mình khuyên ngay từ đầu

Tất cả module nên dùng:

```solidity
SystemAccessControl
```

thay vì:

```solidity
ORG_WALLET
```

Ví dụ:

```solidity
modifier onlyCompanyAdmin()
```

```solidity
modifier onlyBranchManager()
```

---

# Một vấn đề lớn hơn mình thấy

Bạn đang lưu:

```solidity
ORG_WALLET immutable
```

trong proxy.

Giả sử:

```text
Công ty đổi ví multisig
```

thì sao?

Toàn bộ:

```text
500 branch
2000 module
```

sẽ vẫn trỏ về ví cũ.

---

# Mình khuyên

Trong proxy chỉ lưu:

```solidity
branchId
```

không lưu:

```solidity
orgWallet
```

Khi cần:

```solidity
OrganizationManager.getBranch(branchId)
```

↓

```solidity
orgWallet
```

---

# Upgrade Strategy

Bạn trả lời:

> Upgrade toàn bộ hệ thống

Vậy Beacon là lựa chọn rất hợp lý.

```text
MEOS Beacon
        │
        ├── Branch1
        ├── Branch2
        ├── Branch3
        └── Branch1000
```

Upgrade:

```solidity
beacon.upgradeTo(newLogic);
```

1000 branch cập nhật ngay.

---

# Roadmap Coding mình đề xuất

## Phase 1 - Core

### Hoàn thành

```text
SystemAccessControl
OrganizationManager
ModuleFactory
BranchBeaconProxy
```

---

## Phase 2 - Module Registry

Tạo:

```solidity
ModuleRegistry.sol
```

quản lý:

```solidity
MODULE_MEOS
MODULE_IQR
MODULE_CRM
```

thay vì để trong:

```solidity
moduleFactories
```

---

## Phase 3 - Module Root Pattern

Ví dụ:

```text
MeosRoot
```

chứa địa chỉ:

```text
PCManager
ZoneManager
BillingManager
PlayTimeManager
```

---

## Phase 4 - Branch Roles

Thêm:

```text
Branch Manager
Cashier
Technician
```

---

## Phase 5 - Data Aggregation

Organization Owner có thể:

```solidity
getAllBranchesRevenue()
```

```solidity
getAllBranchesPCCount()
```

```solidity
getAllBranchesStatistics()
```

---

# Điều mình muốn xem tiếp theo

Để lên bản thiết kế hoàn chỉnh (storage + flow + sequence diagram + contract responsibilities), mình muốn xem thêm:

1. `BranchBeaconProxy.sol` (toàn bộ code)
2. `OrganizationManager.createBranch()`
3. Struct `Organization`
4. Struct `Branch`

Vì hiện tại mình nghi ngờ có một vấn đề kiến trúc khá lớn liên quan tới:

```text
Module Bundle
↔ Root Contract
↔ Proxy Identity
↔ Upgrade Flow
```

và đó sẽ quyết định cách viết toàn bộ MEOS/IQR về sau. Nếu thiết kế sai ở tầng này thì khi có 50 module sẽ rất khó sửa.
