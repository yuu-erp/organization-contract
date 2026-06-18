Với mô hình hệ thống dạng **B2B SaaS (Software as a Service)** và **Multi-tenant (Đa người thuê)** mà bạn vừa mô tả, yêu cầu sinh ra hàng loạt tổ chức, chi nhánh và module độc lập (mỗi module một địa chỉ) đòi hỏi một kiến trúc cực kỳ tối ưu về gas và khả năng quản trị.

Nếu dùng mô hình UUPS thông thường, khi bạn có 1,000 chi nhánh và cần cập nhật logic của module `meos`, bạn sẽ phải thực hiện 1,000 giao dịch nâng cấp — điều này là bất khả thi và tốn kém.

Do đó, kiến trúc hoàn hảo nhất cho hệ thống của bạn là **Beacon Proxy Pattern** kết hợp với **Factory Pattern** và **Centralized Access Control (RBAC)**.

Dưới đây là cách triển khai proxies chi tiết cho hệ thống của bạn:

---

### 1. Phân bổ kiến trúc tổng thể

Hệ thống của bạn sẽ được chia thành 3 nhóm Smart Contract chính:

#### Nhóm 1: Core & Registry (Chỉ có 1 bản duy nhất trên toàn hệ thống)

- **`SystemAccessControl`**: Quản lý 3 roles (`Owner`, `OpsAdmin`, `CompanyAdmin`).
- **`OrganizationFactory`**: "Nhà máy" dùng để sinh ra các tổ chức và chi nhánh.
- _Lưu ý:_ Các contract lõi này nên được thiết kế dưới dạng **UUPS Proxy** để bản thân hệ thống lõi cũng có thể nâng cấp được bởi `Owner`.

#### Nhóm 2: Beacons & Implementations (Chứa Logic của các Modules)

Đây là phần lõi của logic tính năng. Mỗi module sẽ có một bộ Hợp đồng Logic và một Ngọn hải đăng (Beacon) đi kèm:

- **Module MEOS**: Có `MeosLogic.sol` và `MeosBeacon.sol`.
- **Module IQR**: Có `IqrLogic.sol` và `IqrBeacon.sol`.
- **Module Loyalty**: Có `LoyaltyLogic.sol` và `LoyaltyBeacon.sol`.

#### Nhóm 3: Các Bản Sao (Beacon Proxies) - Sinh ra động

Đây là các địa chỉ thực tế cấp phát cho các chi nhánh. Khi một chi nhánh bật module, Factory sẽ không deploy lại toàn bộ code mà chỉ deploy một `BeaconProxy` rất nhẹ.

- Ví dụ: Chi nhánh 1 bật MEOS -> Sinh ra `BeaconProxy_Meos_CN1`. Proxy này lưu state của Chi nhánh 1, nhưng trỏ về `MeosBeacon` để đọc logic.

---

### 2. Luồng hoạt động và Quyền hạn (Roles)

Đây là cách 3 roles tương tác với kiến trúc Proxy này:

#### BƯỚC 1: Khởi tạo hệ thống (Bởi `Owner`)

1. `Owner` deploy `SystemAccessControl` và phân quyền cho `Ops Admin`.
2. `Owner` (hoặc Ops) deploy các file Logic: `MeosLogic`, `IqrLogic`, `LoyaltyLogic`.
3. `Owner` deploy các **Beacon**: `MeosBeacon` (trỏ vào `MeosLogic`), `IqrBeacon` (trỏ vào `IqrLogic`)...
4. `Owner` deploy `OrganizationFactory` (lưu trữ địa chỉ của các Beacons).

#### BƯỚC 2: Vận hành hệ thống (Bởi `Company Admin` / `Ops Admin`)

1. `Company Admin` gọi hàm `createOrganization("CyberKing Net Cafe")` trên Factory.
2. `Company Admin` gọi hàm `createBranch("Chi Nhánh 1")`.
3. **Kích hoạt Module (Bước quan trọng nhất):** `Company Admin` gọi hàm `enableModule(branchId, "MEOS")`.

- Lúc này, Smart Contract `Factory` sẽ tự động sinh ra một file **`BeaconProxy`** mới.
- `BeaconProxy` này được gắn địa chỉ của `MeosBeacon`.
- **Kết quả:** Bạn có một địa chỉ contract mới toanh chỉ phục vụ tính tiền máy trạm cho Chi nhánh 1.

4. Làm tương tự cho module `IQR` và `Loyalty`. Đối với Chi nhánh 2, chỉ gọi `enableModule` cho `MEOS`.

#### BƯỚC 3: Nâng cấp hệ thống (Bởi `Owner` hoặc `Ops Admin`)

Giả sử bạn cần update tính năng nạp tiền cho hệ thống MEOS ở toàn bộ các tiệm net:

1. `Ops Admin` viết code `MeosLogicV2.sol` và deploy nó lên mạng (chỉ là 1 file logic mới).
2. `Owner` (nắm quyền cao nhất) gọi hàm `upgradeTo(địa chỉ_MeosLogicV2)` **trên hợp đồng `MeosBeacon**`.
3. **Kết quả:** Ngay lập tức, 10,000 cái `BeaconProxy` MEOS ở tất cả các chi nhánh sẽ tự động chuyển sang chạy logic của V2 mà không làm mất dữ liệu người dùng tại từng chi nhánh, và chỉ tốn đúng 1 giao dịch duy nhất của Owner.

---

### 3. Cấu trúc thư mục tương ứng

Với hệ thống này, thư mục dự án của bạn sẽ chuyên nghiệp và quy mô như sau:

```text
contracts/
├── core/
│   ├── SystemAccessControl.sol     # (UUPS) Quản lý Owner, Ops, Company Admin
│   ├── OrganizationFactory.sol     # (UUPS) Hàm tạo Org, Branch và đẻ ra Proxies
│   └── interfaces/
├── modules/
│   ├── meos/
│   │   ├── MeosLogicV1.sol         # Chứa logic máy trạm
│   │   └── MeosStorage.sol         # Định nghĩa các biến của tiệm net
│   ├── iqr/
│   │   └── IqrLogicV1.sol          # Chứa logic đồ ăn
│   └── loyalty/
│       └── LoyaltyLogicV1.sol      # Chứa logic điểm thưởng
└── proxies/
    ├── core/
    │   └── UUPSProxy.sol           # Dùng để deploy SystemAccessControl & Factory
    └── modules/
        ├── ProjectBeacon.sol       # (Kế thừa UpgradeableBeacon)
        └── ProjectBeaconProxy.sol  # (Kế thừa BeaconProxy - sinh ra cho mỗi chi nhánh)

```

### Ưu điểm tuyệt đối của mô hình này cho B2B:

1. **Cách ly dữ liệu:** Data của chi nhánh 1 (doanh thu, user) nằm hoàn toàn ở `BeaconProxy 1`, tách biệt với chi nhánh 2. Không sợ lỗi logic làm sai lệch quỹ của chi nhánh khác.
2. **Mở rộng tính năng:** Khi chi nhánh 2 muốn có thêm `IQR`, `Company Admin` chỉ việc bấm nút sinh ra proxy mới. Các module không ảnh hưởng tới nhau.
3. **Bảo mật:** `Company Admin` chỉ được quyền "bật/tắt" module và vận hành. Việc "nâng cấp" hoặc "thay đổi logic tính tiền" được kiểm soát nghiêm ngặt bởi `Owner` ở tầng Beacon.

Cách thiết kế này đang là "tiêu chuẩn vàng" (Golden Standard) cho các dự án Web3 cung cấp hạ tầng dưới dạng Service. Bạn có thắc mắc cụ thể về cách viết code cho hàm `enableModule` trong Factory không?
