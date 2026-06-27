import { MtnContract } from "@metanodejs/mtn-contract";
import { moduleRegistryABI } from "./abi";

export class ModuleRegistryContract extends MtnContract {
  constructor(from: string, to: string) {
    super({ from, to });
  }

  public async getOrgModules(orgId: number): Promise<{ keys: string[] }> {
    return this.sendTransaction<{ keys: string[] }>({
      abiData: moduleRegistryABI.getOrgModules,
      functionName: "getOrgModules",
      inputData: { orgId },
      feeType: "read",
    });
  }

  public async isOrgSubscribed(
    orgId: number,
    moduleKey: string,
  ): Promise<boolean> {
    return this.sendTransaction<boolean>({
      abiData: moduleRegistryABI.isOrgSubscribed,
      functionName: "isOrgSubscribed",
      inputData: { orgId, moduleKey },
      feeType: "read",
    });
  }

  public async subscribeOrgToModule(
    orgId: number,
    moduleKey: string,
  ): Promise<void> {
    await this.sendTransaction<void>({
      abiData: moduleRegistryABI.subscribeOrgToModule,
      functionName: "subscribeOrgToModule",
      inputData: { orgId, moduleKey },
      feeType: "read",
    });
  }

  public async unsubscribeOrgFromModule(
    orgId: number,
    moduleKey: string,
  ): Promise<void> {
    await this.sendTransaction<void>({
      abiData: moduleRegistryABI.unsubscribeOrgFromModule,
      functionName: "unsubscribeOrgFromModule",
      inputData: { orgId, moduleKey },
      feeType: "read",
    });
  }

  public async getModuleFactory(key: string): Promise<string> {
    return this.sendTransaction<string>({
      abiData: moduleRegistryABI.getModuleFactory,
      functionName: "getModuleFactory",
      inputData: { key },
      feeType: "read",
    });
  }
}
