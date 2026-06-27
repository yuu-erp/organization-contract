import { MtnContract } from "@metanodejs/mtn-contract";
import { organizationMetadataRegistryABI } from "./abi";

export interface OrganizationMetadata {
  name: string;
  organizationAddress: string;
  phoneNumber: string;
}

export interface BranchMetadata {
  name: string;
  organizationAddress: string;
  phoneNumber: string;
  code: string;
}

export class OrganizationMetadataRegistryContract extends MtnContract {
  constructor(from: string, to: string) {
    super({ from, to });
  }

  private read<T>(
    functionName: string,
    inputData: Record<string, unknown> = {},
  ): Promise<T> {
    return this.sendTransaction<T>({
      abiData: organizationMetadataRegistryABI[functionName],
      functionName,
      inputData,
      feeType: "read",
    });
  }

  private write<T>(
    functionName: string,
    inputData: Record<string, unknown> = {},
  ): Promise<T> {
    return this.sendTransaction<T>({
      abiData: organizationMetadataRegistryABI[functionName],
      functionName,
      inputData,
      feeType: "read",
    });
  }

  public async setOrganizationMetadata(
    organizationId: number,
    name: string,
    organizationAddress: string,
    phoneNumber: string,
  ): Promise<void> {
    await this.write("setOrganizationMetadata", {
      organizationId,
      name,
      organizationAddress,
      phoneNumber,
    });
  }

  public async setBranchMetadata(
    branchId: number,
    name: string,
    organizationAddress: string,
    phoneNumber: string,
    code: string,
  ): Promise<void> {
    await this.write("setBranchMetadata", {
      branchId,
      name,
      organizationAddress,
      phoneNumber,
      code,
    });
  }

  public async getOrganizationMetadata(
    organizationId: number,
  ): Promise<OrganizationMetadata> {
    return this.read<OrganizationMetadata>("getOrganizationMetadata", {
      organizationId,
    });
  }

  public async getBranchMetadata(branchId: number): Promise<BranchMetadata> {
    return this.read<BranchMetadata>("getBranchMetadata", { branchId });
  }
}
