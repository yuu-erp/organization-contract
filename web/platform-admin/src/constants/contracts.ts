import deployData from "../../../../deployments/system_deploy.json";

export const CONTRACTS_ADDRESS = {
  SYSTEM_ACCESS_CONTROL: deployData.SystemAccessControl?.proxy || "",
  ORGANIZATION_MANAGER: deployData.OrganizationManager?.proxy || "",
  ORGANIZATION_METADATA_REGISTRY: deployData.OrganizationMetadataRegistry?.proxy || "",
  ORGANIZATION_READER: deployData.OrganizationReader || "",
  MODULE_REGISTRY: (deployData as any).ModuleRegistry?.proxy || "",
  BRANCH_MODULE_MANAGER: (deployData as any).BranchModuleManager?.proxy || "",
};
