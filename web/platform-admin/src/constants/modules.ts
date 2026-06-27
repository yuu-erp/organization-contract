/**
 * Module Keys — keccak256 hashes matching Solidity `ModuleKeys.sol`
 *
 * ```solidity
 * bytes32 public constant MODULE_MEOS    = keccak256("MODULE_MEOS");
 * bytes32 public constant MODULE_IQR     = keccak256("MODULE_IQR");
 * bytes32 public constant MODULE_LOYALTY = keccak256("MODULE_LOYALTY");
 * ```
 */

export const MODULE_KEYS = {
  MODULE_MEOS:
    "4e3f97e2fd82aa26a37513d1c6bee19402c482ff120c710ecb38fd2a3a582396",
  MODULE_IQR:
    "6c6381109a825b1f9bbbab19d42ecdbd2f839854c29f0a54785f0c87d63989d6",
  MODULE_LOYALTY:
    "c24d4f8056beeb9d629f71324584846bc0dde6e9210001659b471c67f93cb818",
} as const;

/** Human-readable labels for each module */
export const MODULE_INFO: {
  key: string;
  name: string;
  label: string;
  color: string;
}[] = [
  {
    key: MODULE_KEYS.MODULE_MEOS,
    name: "MEOS",
    label: "MEOS (Cyber Core)",
    color: "text-teal-400",
  },
  {
    key: MODULE_KEYS.MODULE_IQR,
    name: "IQR",
    label: "IQR (Internet Quality Registry)",
    color: "text-cyan-400",
  },
  {
    key: MODULE_KEYS.MODULE_LOYALTY,
    name: "LOYALTY",
    label: "LOYALTY (Rewards System)",
    color: "text-purple-400",
  },
];

/** Lookup a module label by its bytes32 key */
export function getModuleLabel(key: string): string {
  const found = MODULE_INFO.find(
    (m) => m.key.toLowerCase() === key.toLowerCase(),
  );
  return found?.label ?? key;
}
