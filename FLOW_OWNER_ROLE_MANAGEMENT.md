# Luồng Owner Tạo Manager và Co-owner Cho Các Chi Nhánh

Tài liệu này mô tả chi tiết toàn bộ luồng nghiệp vụ khi **Owner (Chủ tổ chức)** muốn bổ nhiệm hoặc quản lý các vai trò cấp cao (như **Co-owner** và **Manager**) cho một hoặc nhiều chi nhánh. Kiến trúc hiện tại sử dụng mô hình quản trị tách bạch giữa `BranchStaffManager` (Quản lý hồ sơ) và `BranchGovernanceManager` (Quản trị & Biểu quyết).

---

## 1. Nguyên Tắc Cốt Lõi

1. **Owner là Quyền lực Tối cao Toàn cục (Global Absolute Bypass):** Owner của một tổ chức (`OrganizationManager`) mặc định có quyền cao nhất trên mọi chi nhánh thuộc tổ chức đó mà không cần có hồ sơ nhân sự (StaffProfile) lưu trực tiếp tại chi nhánh.
2. **Khởi tạo trực tiếp (Zero Co-owner Bypass):** Nếu chi nhánh _chưa có bất kỳ Co-owner nào_, Owner có quyền bổ nhiệm trực tiếp Co-owner hoặc Manager ngay lập tức mà không cần bỏ phiếu.
3. **Bắt buộc Biểu quyết (Decentralized Branch Gov):** Nếu chi nhánh _đã có ít nhất 1 Co-owner_, thì mọi thao tác tạo mới, sửa đổi, hoặc bãi nhiệm Co-owner/Manager **BẮT BUỘC** phải thông qua quy trình biểu quyết bằng `BranchGovernanceManager` (Guardrail 5).
4. **Checkpoint Chống Thao Túng:** Các Co-owner chỉ được quyền vote cho những Proposal được tạo ra _sau hoặc cùng thời điểm_ họ được bổ nhiệm. Owner không bị giới hạn bởi luật này.

---

## 2. Luồng Thực Hiện Cho 1 Chi Nhánh Cụ Thể

Để bổ nhiệm Co-owner hoặc Manager cho Chi nhánh `branchId`, quy trình như sau:

### Bước 1: Lấy địa chỉ Smart Contract của Chi Nhánh

Frontend cần gọi tới `BranchModuleManager` để lấy ra 2 proxy chính của chi nhánh:

```typescript
const branchStaffManagerAddress =
  await branchModuleManager.getBranchStaffManager(branchId);
const branchGovManagerAddress =
  await branchModuleManager.branchGovernanceManagers(branchId);
```

### Bước 2: Kiểm tra số lượng Co-owner hiện tại

Truy vấn xem chi nhánh đã có Co-owner nào chưa bằng cách gọi `BranchStaffManager`:

```typescript
const coOwnerCount = await branchStaffManager.coOwnerCount();
```

---

### TÌNH HUỐNG A: `coOwnerCount == 0` (Bổ nhiệm Trực Tiếp)

Trong giai đoạn đầu mới tạo chi nhánh (chưa có Co-owner), Owner có thể bỏ qua toàn bộ rào cản Governance và gọi trực tiếp vào hợp đồng nhân sự.

**Thực thi:** Owner gọi hàm `setGlobalProfile` trên `BranchStaffManager`.

```solidity
// Trong Smart Contract BranchStaffManager
function setGlobalProfile(address staff, uint8 role, uint248 globalPerms) external;
```

- Bổ nhiệm **Co-owner**: Truyền `role = 1`.
- Bổ nhiệm **Manager**: Truyền `role = 2`.
- Giao dịch thực thi và thay đổi cấu hình nhân sự ngay lập tức. Hệ thống đồng thời lưu lại `coOwnerAppointedTime[staff] = block.timestamp` nếu bổ nhiệm Co-owner.

---

### TÌNH HUỐNG B: `coOwnerCount > 0` (Bổ nhiệm qua Biểu Quyết)

Lúc này, Guardrail 5 của `BranchStaffManager` đã được kích hoạt. Không ai (kể cả Owner) có thể gọi trực tiếp `setGlobalProfile` cho các vai trò cấp cao. Mọi yêu cầu phải gửi qua `BranchGovernanceManager`.

#### 3.1. Tạo Đề Xuất (Proposal)

Owner gọi hàm `createProposal` trên `BranchGovernanceManager`:

```solidity
function createProposal(
    GovernanceTypes.ProposalType proposalType, // Truyền AddOrUpdateProfile (0)
    address target,                            // Địa chỉ ví nhân sự mới
    uint8 role,                                // 1 (Co-owner) hoặc 2 (Manager)
    uint248 globalPerms,                       // Bitmask (thường là 0 cho cấp cao)
    bytes32 moduleKey,                         // Tham số thừa (để rỗng/0x0)
    uint256 modulePermBitmask,                 // Tham số thừa (để rỗng/0)
    bytes32 metadataHash                       // Hash thông tin (Tên, SDT, Avatar) để verify
) external returns (uint256 proposalId);
```

- Khi tạo, Proposal sẽ snapshot `totalVotersAtCreation` (Bao gồm Owner + số Co-owner hiện tại) và lưu `creationTime`.

#### 3.2. Bỏ Phiếu (Voting)

Owner và các Co-owner hiện tại gọi hàm `voteProposal` để bỏ phiếu (Yes/No).

```solidity
function voteProposal(uint256 proposalId, bool support) external;
```

- **Checkpoint Rule:** Nếu một Co-owner nào đó được bổ nhiệm ở timestamp lớn hơn `proposal.creationTime`, giao dịch vote của họ sẽ bị Revert. Tuy nhiên, Owner luôn được vote bình thường.

#### 3.3. Thực Thi (Execution)

Khi thời gian biểu quyết chưa hết nhưng đã gom đủ quá nửa số phiếu thuận (`yesVotes > totalVotersAtCreation / 2`), bất kỳ ai cũng có thể gọi `executeProposal`.

```solidity
function executeProposal(
    uint256 proposalId,
    string calldata name,
    string calldata phone,
    string calldata avatar
) external;
```

- Proposal khi được thực thi sẽ mượn quyền của Governance (Governance Proxy) gọi sang `BranchStaffManager.setGlobalProfile(...)` để hoàn tất việc cấp quyền.

---

## 3. Đặc Quyền Của Owner (Chống Nổi Loạn / Tối Cao)

Ngay cả trong Tình huống B (phải thông qua biểu quyết), Owner vẫn luôn nắm đằng chuôi để kiểm soát các chi nhánh:

1. **Vote Mặc Định:** Owner luôn chiếm 1 phiếu bầu hợp lệ trong `totalVotersAtCreation`.
2. **Quyền Hủy Bỏ (Cancel):** Owner có quyền gọi `BranchGovernanceManager.cancelProposal(proposalId)` để Hủy (Canceled) bất kỳ Proposal nào đang ở trạng thái Active, ngăn chặn các Co-owner tự ý thông qua một luật lệ hay nhân sự không được Owner chấp thuận.

---

## 4. Xử Lý Cho Nhiều Chi Nhánh (Multiple Branches)

Nếu Owner muốn áp dụng một nhân sự làm Manager hoặc Co-owner cho **nhiều chi nhánh cùng một lúc**, phía Frontend sẽ cần xử lý vòng lặp qua từng chi nhánh.

Bởi vì mỗi chi nhánh là một hợp đồng Proxy phân tán biệt lập:

1. Frontend sẽ lặp mảng `[branchId_1, branchId_2, ..., branchId_n]`.
2. Truy xuất Proxy Address của `BranchStaffManager` và `BranchGovernanceManager` tương ứng với mỗi `branchId`.
3. Kiểm tra số lượng Co-owner trên từng nhánh:
   - Các nhánh `coOwnerCount == 0`: gom vào 1 mảng dữ liệu (Calldata) để gọi hàm `setGlobalProfile` trực tiếp trên các `BranchStaffManager`.
   - Các nhánh `coOwnerCount > 0`: gom vào 1 mảng Calldata khác để gọi `createProposal` trên các `BranchGovernanceManager`.
4. Nếu Frontend có cơ chế hỗ trợ multicall ở cấp độ Tổ chức hoặc thông qua ví User, việc thực thi cho nhiều chi nhánh có thể được gom vào chung một Transaction lớn.
