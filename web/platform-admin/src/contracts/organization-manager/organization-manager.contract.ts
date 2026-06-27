import { MtnContract } from "@metanodejs/mtn-contract";
import { organizationManagerABI } from "./abi";

export class OrganizationManagerContract extends MtnContract {
  constructor(from: string, to: string) {
    super({ from, to });
  }

  private read<T>(
    functionName: string,
    inputData: Record<string, unknown> = {},
  ): Promise<T> {
    return this.sendTransaction<T>({
      abiData: organizationManagerABI[functionName],
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
      abiData: organizationManagerABI[functionName],
      functionName,
      inputData,
      feeType: "read",
    });
  }

  public async createOrganization(
    owner: string,
    moduleKeys: string[],
  ): Promise<number> {
    const res = await this.write<string>("createOrganization", {
      owner,
      moduleKeys,
    });
    return Number(res);
  }

  public async createBranch(
    organizationId: number,
    moduleKeysToEnable: string[],
  ): Promise<number> {
    const res = await this.write<string>("createBranch", {
      organizationId,
      moduleKeysToEnable,
    });
    return Number(res);
  }

  public async getOrganizationIdByOwner(owner: string): Promise<number> {
    const res = await this.read<string>("getOrganizationIdByOwner", { owner });
    return Number(res);
  }

  public async getOrganizationBranches(
    organizationId: number,
  ): Promise<number[]> {
    const res = await this.read<string[]>("getOrganizationBranches", {
      organizationId,
    });
    return res.map(Number);
  }

  public async organizationExists(organizationId: number): Promise<boolean> {
    return this.read<boolean>("organizationExists", { organizationId });
  }

  public async getBranchOrgId(branchId: number): Promise<number> {
    const res = await this.read<string>("getBranchOrgId", { branchId });
    return Number(res);
  }

  public async organizationCounter(): Promise<number> {
    const res = await this.read<string>("organizationCounter");
    return Number(res);
  }

  public async branchCounter(): Promise<number> {
    const res = await this.read<string>("branchCounter");
    return Number(res);
  }

  public async branchModuleManager(): Promise<string> {
    return this.read<string>("branchModuleManager");
  }
}
