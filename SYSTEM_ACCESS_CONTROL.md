Chào bạn, để test contract `SystemAccessControl` bằng công cụ **`cast`** (thuộc bộ công cụ Foundry), bạn sẽ cần sử dụng `cast send` cho các hàm thay đổi state (write) và `cast call` cho các hàm chỉ đọc (read).

Vì đây là contract Upgradeable (sử dụng UUPS Proxy), bạn sẽ tương tác trực tiếp với **địa chỉ của Proxy** thay vì địa chỉ của Implementation.

Dưới đây là tập hợp các lệnh `cast` để test các luồng cơ bản.

### 1. Cài đặt các biến môi trường (Optional nhưng khuyên dùng)

Để các lệnh ngắn gọn và dễ copy-paste, bạn nên set các biến môi trường trên terminal trước:

```bash
export RPC_URL="http://localhost:8545" # Hoặc URL của testnet/mainnet
export PRIVATE_KEY="0x_private_key_cua_ban"
export PROXY_ADDRESS="0x_dia_chi_proxy_cua_contract"
export ADMIN_ADDRESS="0x_dia_chi_admin_khoi_tao"
export TARGET_ADDRESS="0x_dia_chi_can_kiem_tra_hoac_cap_quyen"

# Giả sử RoleHashes của bạn được tạo từ keccak256 của string
export PLATFORM_ADMIN_ROLE=$(cast keccak "PLATFORM_ADMIN_ROLE")
export DEFAULT_ADMIN_ROLE="0x0000000000000000000000000000000000000000000000000000000000000000"

```

---

### 2. Các lệnh ghi dữ liệu (Write Functions) - Dùng `cast send`

**Khởi tạo Contract (`initialize`)**
Lệnh này chỉ chạy được 1 lần duy nhất sau khi deploy Proxy để set `defaultAdmin`.

```bash
cast send $PROXY_ADDRESS \
  "initialize(address)" $ADMIN_ADDRESS \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY

```

**Cấp quyền Platform Admin (`grantRole`)**
Hàm này được kế thừa từ `AccessControlUpgradeable`. Yêu cầu người gọi (từ `$PRIVATE_KEY`) phải có quyền Admin của role này (ở đây là `DEFAULT_ADMIN_ROLE`).

```bash
cast send $PROXY_ADDRESS \
  "grantRole(bytes32,address)" $PLATFORM_ADMIN_ROLE $TARGET_ADDRESS \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY

```

**Thu hồi quyền (`revokeRole`)**
Thu hồi quyền của một user.

```bash
cast send $PROXY_ADDRESS \
  "revokeRole(bytes32,address)" $PLATFORM_ADMIN_ROLE $TARGET_ADDRESS \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY

```

---

### 3. Các lệnh đọc dữ liệu (Read Functions) - Dùng `cast call`

Các lệnh này không tốn phí gas và trả về kết quả ngay lập tức.

**Kiểm tra xem ví có phải là Platform Admin không (`isPlatformAdmin`)**
Hàm custom của bạn trong contract:

```bash
cast call $PROXY_ADDRESS \
  "isPlatformAdmin(address)(bool)" $TARGET_ADDRESS \
  --rpc-url $RPC_URL

```

_(Kết quả trả về sẽ là `true` hoặc `false`)_

**Kiểm tra Role bất kỳ (`hasRole`)**
Hàm gốc từ AccessControl, hữu ích để check `DEFAULT_ADMIN_ROLE`.

```bash
cast call $PROXY_ADDRESS \
  "hasRole(bytes32,address)(bool)" $DEFAULT_ADMIN_ROLE $ADMIN_ADDRESS \
  --rpc-url $RPC_URL

```

**Kiểm tra Role Admin của một Role (`getRoleAdmin`)**
Kiểm tra xem role nào đang quản lý `PLATFORM_ADMIN_ROLE` (Theo hàm `initialize` thì nó phải trả về chuỗi 0x00... của `DEFAULT_ADMIN_ROLE`).

```bash
cast call $PROXY_ADDRESS \
  "getRoleAdmin(bytes32)(bytes32)" $PLATFORM_ADMIN_ROLE \
  --rpc-url $RPC_URL

```

---

### 4. Xử lý Lỗi (Troubleshooting)

Nếu bạn gặp lỗi Revert khi test bằng `cast`, bạn có thể thêm flag `--trace` vào cuối các lệnh `cast send` hoặc `cast call` để xem chi tiết Call Trace và biết chính xác dòng nào (hoặc Custom Error nào) gây ra lỗi.

Ví dụ:

```bash
cast send $PROXY_ADDRESS "initialize(address)" $ADMIN_ADDRESS --rpc-url $RPC_URL --private-key $PRIVATE_KEY --trace

```

_(Nếu bạn gọi `initialize` lần thứ 2, nó sẽ revert với lỗi `InvalidInitialization()`)_
