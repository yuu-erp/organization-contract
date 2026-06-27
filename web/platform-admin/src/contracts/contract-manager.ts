import { SystemAccessControlContract } from "./system-access-control/system-access-control.contract";
import { OrganizationManagerContract } from "./organization-manager/organization-manager.contract";
import { OrganizationMetadataRegistryContract } from "./organization-metadata-registry/organization-metadata-registry.contract";
import { OrganizationReaderContract } from "./organization-reader/organization-reader.contract";
import { BranchModuleManagerContract } from "./branch-module-manager/branch-module-manager.contract";
import { ModuleRegistryContract } from "./module-registry/module-registry.contract";
import { CONTRACTS_ADDRESS } from "../constants/contracts";

class ContractManager {
  private static instance: ContractManager;
  private constructor() {}

  public static getInstance(): ContractManager {
    if (!ContractManager.instance) {
      ContractManager.instance = new ContractManager();
    }
    return ContractManager.instance;
  }

  private _systemAccessControl: SystemAccessControlContract | null = null;
  private _organizationManager: OrganizationManagerContract | null = null;
  private _organizationMetadataRegistry: OrganizationMetadataRegistryContract | null =
    null;
  private _organizationReader: OrganizationReaderContract | null = null;
  private _moduleRegistry: ModuleRegistryContract | null = null;
  private _walletAddress: string | null = null;

  public init(walletAddress: string): void {
    if (!walletAddress) {
      throw new Error("[ContractManager] Wallet address is required.");
    }
    if (this._walletAddress === walletAddress && this._organizationManager) {
      return;
    }
    this._walletAddress = walletAddress;

    this._systemAccessControl = new SystemAccessControlContract(
      walletAddress,
      CONTRACTS_ADDRESS.SYSTEM_ACCESS_CONTROL,
    );
    this._organizationManager = new OrganizationManagerContract(
      walletAddress,
      CONTRACTS_ADDRESS.ORGANIZATION_MANAGER,
    );
    this._organizationMetadataRegistry =
      new OrganizationMetadataRegistryContract(
        walletAddress,
        CONTRACTS_ADDRESS.ORGANIZATION_METADATA_REGISTRY,
      );
    this._organizationReader = new OrganizationReaderContract(
      walletAddress,
      CONTRACTS_ADDRESS.ORGANIZATION_READER,
    );
    this._moduleRegistry = new ModuleRegistryContract(
      walletAddress,
      CONTRACTS_ADDRESS.MODULE_REGISTRY,
    );
  }

  public get systemAccessControl(): SystemAccessControlContract {
    if (!this._systemAccessControl) {
      throw new Error(
        "[ContractManager] Not initialized. Call init(walletAddress) first.",
      );
    }
    return this._systemAccessControl;
  }

  public get organizationManager(): OrganizationManagerContract {
    if (!this._organizationManager) {
      throw new Error(
        "[ContractManager] Not initialized. Call init(walletAddress) first.",
      );
    }
    return this._organizationManager;
  }

  public get organizationMetadataRegistry(): OrganizationMetadataRegistryContract {
    if (!this._organizationMetadataRegistry) {
      throw new Error(
        "[ContractManager] Not initialized. Call init(walletAddress) first.",
      );
    }
    return this._organizationMetadataRegistry;
  }

  public get organizationReader(): OrganizationReaderContract {
    if (!this._organizationReader) {
      throw new Error(
        "[ContractManager] Not initialized. Call init(walletAddress) first.",
      );
    }
    return this._organizationReader;
  }

  public get moduleRegistry(): ModuleRegistryContract {
    if (!this._moduleRegistry) {
      throw new Error(
        "[ContractManager] Not initialized. Call init(walletAddress) first.",
      );
    }
    return this._moduleRegistry;
  }

  public getBranchModuleManager(address: string): BranchModuleManagerContract {
    if (!this._walletAddress) {
      throw new Error(
        "[ContractManager] Not initialized. Call init(walletAddress) first.",
      );
    }
    return new BranchModuleManagerContract(this._walletAddress, address);
  }
}

export const contractManager = ContractManager.getInstance();
