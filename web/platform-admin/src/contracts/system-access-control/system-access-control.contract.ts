import { MtnContract } from "@metanodejs/mtn-contract";
import { systemAccessControlABI } from "./abi";
export class SystemAccessControlContract extends MtnContract {
  constructor(from: string, to: string) {
    super({ from, to });
  }

  /**
   * Hàm nội bộ để gọi các hàm read/view
   * @param functionName Tên hàm cần gọi
   * @param inputData Dữ liệu đầu vào
   * @returns Kết quả trả về
   */
  private read<T>(
    functionName: string,
    inputData: Record<string, unknown> = {},
  ): Promise<T> {
    return this.sendTransaction<T>({
      abiData: systemAccessControlABI[functionName],
      functionName,
      inputData,
      feeType: "read",
    });
  }

  /**
   * Kiểm tra xem một tài khoản có phải là admin hay không
   * @param account Địa chỉ ví
   * @returns True nếu là admin, ngược lại false
   */
  public async isPlatformAdmin(account: string): Promise<boolean> {
    return this.read("isPlatformAdmin", {
      account,
    });
  }
}
