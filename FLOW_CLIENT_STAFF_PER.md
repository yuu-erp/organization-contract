Một câu hỏi cực kỳ thực tế! Đây chính là điểm giao thoa quan trọng nhất giữa Backend (Smart Contract) và Frontend (Web3 React UI).

Hợp đồng thông minh không có cơ chế API RESTful để trả về danh sách "Các quyền đang có" kèm theo tên hiển thị (label) cho Frontend vẽ giao diện. Máy ảo EVM chỉ quan tâm đến những con số cuối cùng.

Do đó, để Frontend biết được cần render những checkbox nào và tính toán ra `modulePermBitmasks` truyền xuống contract, bạn cần thiết lập một **Nguồn chân lý dùng chung (Shared Source of Truth)**.

Dưới đây là cách các dự án Web3 quy mô lớn thường triển khai bằng TypeScript:

### 1. Xây dựng thư viện Constants dùng chung

Frontend không bao giờ được phép "hardcode" các con số này rải rác trong các component React. Toàn bộ hằng số quyền (Bitmask) và Hash của Module Key phải được định nghĩa ở một file hoặc một package độc lập để cả hệ sinh thái cùng sử dụng.

Ví dụ, bạn tạo một file `permissions.config.ts`:

```typescript
import { keccak256, toUtf8Bytes } from "ethers";

// 1. Định nghĩa Module Keys (Khớp 100% với contract)
export const MODULE_KEYS = {
  MEOS: keccak256(toUtf8Bytes("MODULE_MEOS")),
  IQR: keccak256(toUtf8Bytes("MODULE_IQR")),
};

// 2. Map chính xác các bitmask từ contract sang TypeScript
export const PERMISSIONS = {
  GLOBAL: {
    CASHIER: 1 << 0, // 1
    REPORTS: 1 << 1, // 2
  },
  MEOS: {
    PC_MANAGER: 1 << 0, // 1
    VIP_SETTING: 1 << 1, // 2
  },
  IQR: {
    MENU_MANAGER: 1 << 0, // 1
    KITCHEN: 1 << 1, // 2
  },
} as const;
```

### 2. Cấu hình UI (UI Schema)

Từ các constants trên, bạn định nghĩa các mảng dữ liệu để Frontend render ra các danh sách checkbox cho người quản lý chọn.

```typescript
// Định nghĩa type chuẩn, tuyệt đối không dùng `any`
export interface IPermissionItem {
  id: number;
  label: string;
  description: string;
}

export const MEOS_PERMISSION_UI: IPermissionItem[] = [
  {
    id: PERMISSIONS.MEOS.PC_MANAGER,
    label: "Quản lý Máy Trạm",
    description: "Cho phép mở máy, nạp tiền, bảo trì PC",
  },
  {
    id: PERMISSIONS.MEOS.VIP_SETTING,
    label: "Cấu hình giá VIP",
    description: "Điều chỉnh bảng giá giờ chơi",
  },
];
```

### 3. Logic tính toán Bitmask trên React Component

Khi người dùng tick vào các checkbox trên giao diện, Frontend sẽ lưu các `id` (chính là giá trị bit) vào một mảng state. Khi nhấn nút "Lưu", chúng ta dùng phép **Bitwise OR (`|`)** để gộp tất cả các quyền lại thành một con số `uint256` duy nhất.

```tsx
import React, { useState } from "react";

const StaffRoleManager = () => {
  // Lưu danh sách các quyền MEOS được tick (chứa các số 1, 2...)
  const [selectedMeosPerms, setSelectedMeosPerms] = useState<number[]>([]);

  const handleCheckboxChange = (permId: number, isChecked: boolean) => {
    if (isChecked) {
      setSelectedMeosPerms((prev) => [...prev, permId]);
    } else {
      setSelectedMeosPerms((prev) => prev.filter((id) => id !== permId));
    }
  };

  const handleSubmit = async () => {
    // TÍNH TOÁN BITMASK: Gộp tất cả các quyền lại bằng phép OR (|)
    // Ví dụ: [1, 2] => 1 | 2 = 3
    const finalMeosBitmask: number = selectedMeosPerms.reduce(
      (acc, curr) => acc | curr,
      0,
    );

    // Chuẩn bị payload truyền xuống Contract
    const moduleKeys: string[] = [MODULE_KEYS.MEOS];
    const modulePermBitmasks: number[] = [finalMeosBitmask];
    const globalPerms: number = 0; // Giả sử chưa chọn quyền Global

    try {
      // Gọi hàm contract đã gộp mà chúng ta định nghĩa ở bước trước
      await branchStaffManagerContract.addStaffWithPermissions(
        staffAddress,
        globalPerms,
        moduleKeys,
        modulePermBitmasks,
      );
    } catch (error) {
      console.error("Lỗi khi cấp quyền:", error);
    }
  };

  return (
    <div>
      <h3>Quyền Hạn Tiệm Net (MEOS)</h3>
      {MEOS_PERMISSION_UI.map((perm) => (
        <div key={perm.id}>
          <input
            type="checkbox"
            onChange={(e) => handleCheckboxChange(perm.id, e.target.checked)}
          />
          <label>
            {perm.label} - <i>{perm.description}</i>
          </label>
        </div>
      ))}
      <button onClick={handleSubmit}>Lưu Nhân Viên</button>
    </div>
  );
};
```

### Phương pháp phân phối (Distribution)

Để giữ cho Frontend (React) và Smart Contract luôn đồng bộ hoàn hảo (nếu bạn thêm một quyền mới trong solidity, FE phải tự động nhận được type mới), các hệ sinh thái phát triển thường đóng gói toàn bộ các file Config, Constants, và ABI sinh ra từ TypeChain thành một **Package dùng chung**.

Với hệ thống của bạn, bạn đang sử dụng cấu trúc Monorepo (để Frontend import trực tiếp các file từ thư mục contract) hay dự định publish một package dùng chung (ví dụ một package thuộc dạng hệ thống core) lên local registry để Frontend tải về?
