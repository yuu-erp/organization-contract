import { MtnContract } from "@metanodejs/mtn-contract";
import { organizationReaderABI } from "./abi";

export interface FullOrganizationInfo {
  id: number;
  owner: string;
  active: boolean;
  exists: boolean;
  name: string;
  organizationAddress: string;
  phoneNumber: string;
}

export interface FullBranchInfo {
  id: number;
  owner: string;
  organizationId: number;
  active: boolean;
  exists: boolean;
  name: string;
  organizationAddress: string;
  phoneNumber: string;
  code: string;
}

export class OrganizationReaderContract extends MtnContract {
  constructor(from: string, to: string) {
    super({ from, to });
  }

  private read<T>(
    functionName: string,
    inputData: Record<string, unknown> = {},
  ): Promise<T> {
    return this.sendTransaction<T>({
      abiData: organizationReaderABI[functionName],
      functionName,
      inputData,
      feeType: "read",
    });
  }

  public async getFullOrganizationInfo(organizationId: number): Promise<FullOrganizationInfo> {
    return this.read<FullOrganizationInfo>("getFullOrganizationInfo", { organizationId });
  }

  public async getFullBranchInfo(branchId: number): Promise<FullBranchInfo> {
    return this.read<FullBranchInfo>("getFullBranchInfo", { branchId });
  }

  public async getOrganizationBranchesFull(organizationId: number): Promise<FullBranchInfo[]> {
    return this.read<FullBranchInfo[]>("getOrganizationBranchesFull", { organizationId });
  }
}
