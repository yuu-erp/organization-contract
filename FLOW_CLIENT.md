Để Frontend (FE) tích hợp và chạy được hệ thống Smart Contract đa tầng này, chúng ta cần xây dựng luồng tương tác (user flow) dựa trên **vai trò (Role)** của người dùng đang kết nối ví. Hệ thống của bạn được chia scope rất rõ ràng, do đó FE cũng cần bám sát kiến trúc này.

Với nền tảng là một ứng dụng React/TypeScript, việc đầu tiên là phải đảm bảo định nghĩa Type chặt chẽ cho toàn bộ ABI và hàm gọi contract, tuân thủ tuyệt đối không sử dụng `any` hay ép kiểu bừa bãi.

Dưới đây là luồng thực thi chi tiết cho FE để vận hành hệ thống CyberKing:

### 1. Chuẩn bị cấu hình cốt lõi (Global Config)

FE chỉ cần lưu trữ (hardcode hoặc qua biến môi trường) địa chỉ của **3 hợp đồng lõi (Platform Contracts)**:

- `SystemAccessControl` (Dùng để check quyền Platform Admin).
- `OrganizationManager` (Dùng để tạo Org/Branch và tra cứu `orgId` của user hiện tại).
- `BranchModuleManager` (Dùng để provision và enable modules).

_Lưu ý: FE KHÔNG cần lưu địa chỉ của các hợp đồng chi nhánh (như `BranchStaffManager`, `PCManager`, v.v.) vì chúng được tạo ra động (dynamic deployment). FE sẽ query chúng on-chain._

---

### 2. Luồng Onboarding (Dành cho Chủ hệ thống - Platform Admin)

Đây là luồng dành riêng cho team vận hành của bạn để khởi tạo khách hàng mới (Chủ chuỗi Cyber).

1. **Tạo Tổ chức (Org):**

- FE gọi: `OrganizationManager.createOrganization(ownerAddress, [keccak256("MODULE_MEOS")])`.
- Hệ thống trả về `orgId` (kiểu `uint48`).

2. **Tạo Chi nhánh đầu tiên:**

- FE gọi: `OrganizationManager.createBranch(orgId, [keccak256("MODULE_MEOS")])`.
- Hệ thống trả về `branchId` (kiểu `uint48`).

3. **Provision & Kích hoạt Module:**

- FE gọi: `BranchModuleManager.provisionBranch(branchId, orgId)`. (Deploy `BranchStaffManager`).
- FE gọi: `BranchModuleManager.enableModule(branchId, keccak256("MODULE_MEOS"))`.
- **Thao tác quan trọng:** FE cần bắt sự kiện `ModuleEnabled(branchId, moduleKey, moduleRoot)` để lấy ra địa chỉ của `MeosRoot` contract vừa được deploy, hoặc query lại bằng hàm `getModuleRoot(branchId, moduleKey)`.

---

### 3. Luồng Quản trị (Dành cho Owner / Manager của Cyber)

Khi Chủ tiệm hoặc Quản lý login vào hệ thống, FE cần tự động định vị ngữ cảnh (Context) của họ.

1. **Xác định ngữ cảnh đăng nhập:**

- FE gọi `OrganizationManager.getOrganizationIdByOwner(userWallet)` để biết họ thuộc `orgId` nào.
- FE gọi `OrganizationManager.getOrganizationBranches(orgId)` để lấy danh sách `branchId` họ sở hữu, từ đó render UI chọn chi nhánh (Select Branch).

2. **Quản lý nhân sự (Gán quyền Manager/Staff):**

- Khi user chọn Chi nhánh A (`branchId`), FE gọi `BranchModuleManager.getBranchStaffManager(branchId)` để lấy địa chỉ hợp đồng nhân sự của nhánh đó.
- Khởi tạo instance của `BranchStaffManager` trên FE.
- FE gọi `BranchStaffManager.assignRole(staffWalletAddress, ROLE_STAFF)` để thêm nhân viên.

---

### 4. Luồng Vận hành Nghiệp vụ (Dành cho Staff / Manager)

Đây là luồng làm việc hằng ngày (thêm máy tính, tạo hội viên). Khi Staff chọn làm việc tại một `branchId` cụ thể:

1. **Định tuyến (Routing) đến hợp đồng nghiệp vụ:**

- FE gọi `BranchModuleManager.getModuleRoot(branchId, keccak256("MODULE_MEOS"))` để lấy địa chỉ `MeosRoot`.
- FE gọi `MeosRoot.getSubContracts()` để lấy ra địa chỉ thực tế của `PCManager` và `AccountManager`.

2. **Thực thi nghiệp vụ:**

- Để thêm máy: FE khởi tạo instance `PCManager` (từ địa chỉ vừa lấy) và gọi `PCManager.addPC()`. Contract sẽ tự động cross-check quyền với `BranchStaffManager` on-chain.
- Để thêm hội viên: FE gọi `AccountManager.registerUser(username, userWallet)`.

---

### Mẫu TypeScript Tích hợp (Strict Type)

Dưới đây là một ví dụ về service layer trên FE sử dụng `ethers` (v6) hoặc `viem`, áp dụng định nghĩa type nghiêm ngặt:

```typescript
import { BrowserProvider, Contract, BytesLike } from "ethers";

// 1. Định nghĩa chuẩn xác ABI Interfaces
export interface IBranchModuleManager extends Contract {
  provisionBranch(
    branchId: number,
    orgId: number,
  ): Promise<ethers.ContractTransactionResponse>;
  enableModule(
    branchId: number,
    moduleKey: BytesLike,
  ): Promise<ethers.ContractTransactionResponse>;
  getModuleRoot(branchId: number, moduleKey: BytesLike): Promise<string>;
}

export interface IMeosRoot extends Contract {
  getSubContracts(): Promise<[string, string]>; // Trả về [pcManager, accountManager]
}

export interface IPCManager extends Contract {
  addPC(): Promise<ethers.ContractTransactionResponse>;
}

// 2. Logic gọi hàm (Service class hoặc Custom Hook)
export const getPCManagerAddress = async (
  provider: BrowserProvider,
  branchModuleManagerAddress: string,
  branchId: number,
  meosModuleKey: string, // hash của "MODULE_MEOS"
): Promise<string> => {
  // Không ép kiểu bằng 'any', sử dụng generic/interface của ethers
  const branchManager = new Contract(
    branchModuleManagerAddress,
    BranchModuleManagerABI,
    provider,
  ) as unknown as IBranchModuleManager;

  // Lấy MeosRoot Address
  const meosRootAddress: string = await branchManager.getModuleRoot(
    branchId,
    meosModuleKey,
  );

  const meosRoot = new Contract(
    meosRootAddress,
    MeosRootABI,
    provider,
  ) as unknown as IMeosRoot;

  // Lấy PC Manager Address
  const [pcManagerAddress, accountManagerAddress] =
    await meosRoot.getSubContracts();

  return pcManagerAddress;
};
```

Bằng cách thiết kế FE gọi theo chuỗi **Registry -> Root -> Sub-contract**, hệ thống Frontend của bạn hoàn toàn tách rời (decoupled) khỏi các bản nâng cấp logic. Khi bạn update logic của `PCManager` ở Backend (đổi ngọn hải đăng Beacon), FE không cần phải thay đổi bất kỳ dòng code nào vì địa chỉ Proxy của `PCManager` vẫn giữ nguyên.

Để tối ưu hóa trải nghiệm người dùng (UX) trên Frontend, bạn dự định sẽ cho phép hệ thống tự động lưu cache (ví dụ: Redis, LocalStorage, hoặc IndexedDB) các địa chỉ sub-contracts này sau lần query đầu tiên, hay sẽ luôn fetch trực tiếp từ blockchain mỗi khi Staff reload trang?
