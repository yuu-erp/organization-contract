import { MtnContract } from "@metanodejs/mtn-contract";

export const branchModuleManagerABI: Record<string, any> = {
  getModuleRoot: {
    type: "function",
    name: "getModuleRoot",
    inputs: [
      { name: "branchId", type: "uint48", internalType: "uint48" },
      { name: "moduleKey", type: "bytes32", internalType: "bytes32" }
    ],
    outputs: [
      { name: "", type: "address", internalType: "address" }
    ],
    stateMutability: "view"
  }
};

export class BranchModuleManagerContract extends MtnContract {
  constructor(from: string, to: string) {
    super({ from, to });
  }

  public async getModuleRoot(branchId: number, moduleKey: string): Promise<string> {
    return this.sendTransaction<string>({
      abiData: branchModuleManagerABI.getModuleRoot,
      functionName: "getModuleRoot",
      inputData: { branchId, moduleKey },
      feeType: "read",
    });
  }

  public async getBranchStaffManager(branchId: number): Promise<string> {
    return this.sendTransaction<string>({
      abiData: {
        type: "function",
        name: "getBranchStaffManager",
        inputs: [{ name: "branchId", type: "uint48", internalType: "uint48" }],
        outputs: [{ name: "", type: "address", internalType: "address" }],
        stateMutability: "view"
      },
      functionName: "getBranchStaffManager",
      inputData: { branchId },
      feeType: "read",
    });
  }

  public async staffManagerBeacon(): Promise<string> {
    return this.sendTransaction<string>({
      abiData: {
        type: "function",
        name: "staffManagerBeacon",
        inputs: [],
        outputs: [{ name: "", type: "address", internalType: "address" }],
        stateMutability: "view"
      },
      functionName: "staffManagerBeacon",
      inputData: {},
      feeType: "read",
    });
  }

  public async moduleRegistry(): Promise<string> {
    return this.sendTransaction<string>({
      abiData: {
        type: "function",
        name: "moduleRegistry",
        inputs: [],
        outputs: [{ name: "", type: "address", internalType: "address" }],
        stateMutability: "view"
      },
      functionName: "moduleRegistry",
      inputData: {},
      feeType: "read",
    });
  }
}
