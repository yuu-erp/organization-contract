import type { AbiItem } from "@metanodejs/system-core";
import abi from "./abi.json";

const typedAbi = abi as unknown as AbiItem[];

export const systemAccessControlABI: Record<string, AbiItem> = typedAbi.reduce(
  (acc, item) => {
    if (item.name) {
      acc[item.name] = item;
    }
    return acc;
  },
  {} as Record<string, AbiItem>,
);
