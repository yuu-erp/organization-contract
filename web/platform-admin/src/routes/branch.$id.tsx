import { connectWallet, getActiveWallet } from "@metanodejs/system-core";
import { createFileRoute, Link } from "@tanstack/react-router";
import {
  ArrowLeft,
  Building,
  CheckCircle2,
  Copy,
  Cpu,
  Globe,
  Loader2,
  MapPin,
  Phone,
  ShieldAlert,
  Wallet,
} from "lucide-react";
import { useEffect, useState } from "react";
import { contractManager } from "../contracts/contract-manager";
import type { FullBranchInfo } from "../contracts/organization-reader/organization-reader.contract";
import { MODULE_KEYS } from "../constants/modules";
import { MtnContract } from "@metanodejs/mtn-contract";

export const Route = createFileRoute("/branch/$id")({
  component: BranchDetail,
});

function BranchDetail() {
  const { id } = Route.useParams();
  const branchId = Number(id);

  const [walletAddress, setWalletAddress] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [branchInfo, setBranchInfo] = useState<FullBranchInfo | null>(null);
  const [moduleAddresses, setModuleAddresses] = useState<{
    meos: string;
    iqr: string;
    loyalty: string;
    manager: string;
    staffManager: string;
    staffManagerBeacon: string;
    moduleRegistry: string;
    meosFactory: string;
    iqrFactory: string;
    loyaltyFactory: string;
  } | null>(null);
  const [copiedKey, setCopiedKey] = useState<string | null>(null);
  const [subContracts, setSubContracts] = useState<{
    pcManager: string;
    accountManager: string;
    posManager: string;
    pointManager: string;
  } | null>(null);

  // Authentication & initialization
  const handleConnectWallet = async () => {
    try {
      setLoading(true);
      await connectWallet();
      const activeWallet = await getActiveWallet();
      if (activeWallet) {
        setWalletAddress(activeWallet.address);
        contractManager.init(activeWallet.address);
        await loadBranchData(activeWallet.address);
      }
    } catch (err) {
      console.error("Wallet connection failed", err);
    } finally {
      setLoading(false);
    }
  };

  const loadBranchData = async (_address: string) => {
    try {
      // 1. Fetch branch core & metadata
      const info =
        await contractManager.organizationReader.getFullBranchInfo(branchId);
      setBranchInfo(info);

      // 2. Fetch Module Manager
      const managerAddr =
        await contractManager.organizationManager.branchModuleManager();
      const moduleMgr = contractManager.getBranchModuleManager(managerAddr);

      // 3. Fetch module manager variables
      const [staffManager, staffManagerBeacon, moduleRegistryAddr] =
        await Promise.all([
          moduleMgr.getBranchStaffManager(branchId),
          moduleMgr.staffManagerBeacon(),
          moduleMgr.moduleRegistry(),
        ]);

      // 4. Fetch module roots & factories
      const [meos, iqr, loyalty, meosFactory, iqrFactory, loyaltyFactory] =
        await Promise.all([
          moduleMgr.getModuleRoot(branchId, MODULE_KEYS.MODULE_MEOS),
          moduleMgr.getModuleRoot(branchId, MODULE_KEYS.MODULE_IQR),
          moduleMgr.getModuleRoot(branchId, MODULE_KEYS.MODULE_LOYALTY),
          contractManager.moduleRegistry.getModuleFactory(
            MODULE_KEYS.MODULE_MEOS,
          ),
          contractManager.moduleRegistry.getModuleFactory(
            MODULE_KEYS.MODULE_IQR,
          ),
          contractManager.moduleRegistry.getModuleFactory(
            MODULE_KEYS.MODULE_LOYALTY,
          ),
        ]);

      setModuleAddresses({
        meos,
        iqr,
        loyalty,
        manager: managerAddr,
        staffManager,
        staffManagerBeacon,
        moduleRegistry: moduleRegistryAddr,
        meosFactory,
        iqrFactory,
        loyaltyFactory,
      });

      // 5. Fetch sub-contracts for each active module root proxy
      let pcManager = "0x0000000000000000000000000000000000000000";
      let accountManager = "0x0000000000000000000000000000000000000000";
      let posManager = "0x0000000000000000000000000000000000000000";
      let pointManager = "0x0000000000000000000000000000000000000000";

      if (meos && meos !== "0x0000000000000000000000000000000000000000") {
        try {
          const meosContract = new MtnContract({ from: _address, to: meos });
          const [pc, acc] = await Promise.all([
            meosContract.sendTransaction<string>({
              abiData: {
                type: "function",
                name: "pcManager",
                inputs: [],
                outputs: [{ name: "", type: "address" }],
                stateMutability: "view",
              },
              functionName: "pcManager",
              inputData: {},
              feeType: "read",
            }),
            meosContract.sendTransaction<string>({
              abiData: {
                type: "function",
                name: "accountManager",
                inputs: [],
                outputs: [{ name: "", type: "address" }],
                stateMutability: "view",
              },
              functionName: "accountManager",
              inputData: {},
              feeType: "read",
            }),
          ]);
          pcManager = pc;
          accountManager = acc;
        } catch (e) {
          console.error("Failed to fetch MEOS sub contracts", e);
        }
      }

      if (iqr && iqr !== "0x0000000000000000000000000000000000000000") {
        try {
          const iqrContract = new MtnContract({ from: _address, to: iqr });
          posManager = await iqrContract.sendTransaction<string>({
            abiData: {
              type: "function",
              name: "posManager",
              inputs: [],
              outputs: [{ name: "", type: "address" }],
              stateMutability: "view",
              },
            functionName: "posManager",
            inputData: {},
            feeType: "read",
          });
        } catch (e) {
          console.error("Failed to fetch IQR sub contracts", e);
        }
      }

      if (loyalty && loyalty !== "0x0000000000000000000000000000000000000000") {
        try {
          const loyaltyContract = new MtnContract({ from: _address, to: loyalty });
          pointManager = await loyaltyContract.sendTransaction<string>({
            abiData: {
              type: "function",
              name: "pointManager",
              inputs: [],
              outputs: [{ name: "", type: "address" }],
              stateMutability: "view",
            },
            functionName: "pointManager",
            inputData: {},
            feeType: "read",
          });
        } catch (e) {
          console.error("Failed to fetch Loyalty sub contracts", e);
        }
      }

      setSubContracts({
        pcManager,
        accountManager,
        posManager,
        pointManager,
      });
    } catch (err) {
      console.error("Failed to load branch details", err);
    }
  };

  useEffect(() => {
    const checkWallet = async () => {
      try {
        const activeWallet = await getActiveWallet();
        if (activeWallet) {
          setWalletAddress(activeWallet.address);
          contractManager.init(activeWallet.address);
          await loadBranchData(activeWallet.address);
        }
      } catch (err) {
        console.error("Failed to detect active wallet", err);
      } finally {
        setLoading(false);
      }
    };
    checkWallet();
  }, [branchId]);

  const copyToClipboard = (text: string, key: string) => {
    navigator.clipboard.writeText(text);
    setCopiedKey(key);
    setTimeout(() => setCopiedKey(null), 2000);
  };

  console.log("moduleAddresses", moduleAddresses);

  if (loading) {
    return (
      <div className="min-h-screen bg-black flex flex-col justify-center items-center gap-4 text-zinc-400">
        <Loader2 className="h-8 w-8 animate-spin text-emerald-500" />
        <p className="text-sm font-medium animate-pulse">
          Đang tải dữ liệu Chi nhánh...
        </p>
      </div>
    );
  }

  if (!walletAddress) {
    return (
      <div className="min-h-screen bg-black flex items-center justify-center p-4">
        <div className="max-w-md w-full rounded-3xl border border-zinc-800 bg-zinc-900/30 p-8 text-center backdrop-blur-xl shadow-2xl">
          <div className="mx-auto w-12 h-12 rounded-full bg-emerald-500/10 flex items-center justify-center mb-6 border border-emerald-500/20">
            <Wallet className="h-6 w-6 text-emerald-400" />
          </div>
          <h2 className="text-2xl font-bold text-white mb-2">Kết nối Ví</h2>
          <p className="text-sm text-zinc-400 mb-6">
            Vui lòng kết nối ví của bạn để xem bộ địa chỉ hợp đồng của Chi nhánh
            #{branchId}.
          </p>
          <button
            onClick={handleConnectWallet}
            className="w-full py-3.5 rounded-xl bg-linear-to-r from-emerald-500 to-teal-500 font-semibold text-black hover:opacity-95 transition-all shadow-[0_4px_20px_rgba(16,185,129,0.2)] cursor-pointer text-sm"
          >
            Kết nối Ví
          </button>
        </div>
      </div>
    );
  }

  if (!branchInfo) {
    return (
      <div className="min-h-screen bg-black flex items-center justify-center p-4">
        <div className="max-w-md w-full rounded-3xl border border-rose-500/10 bg-zinc-900/30 p-8 text-center backdrop-blur-xl">
          <div className="mx-auto w-12 h-12 rounded-full bg-rose-500/10 flex items-center justify-center mb-6 border border-rose-500/20">
            <ShieldAlert className="h-6 w-6 text-rose-400" />
          </div>
          <h2 className="text-2xl font-bold text-white mb-2">
            Không tìm thấy chi nhánh
          </h2>
          <p className="text-sm text-zinc-400 mb-6">
            Chi nhánh #{branchId} không tồn tại hoặc bạn không có quyền xem
            thông tin.
          </p>
          <Link
            to="/"
            className="inline-flex items-center gap-2 text-sm text-emerald-400 hover:text-emerald-300 font-semibold"
          >
            <ArrowLeft className="h-4 w-4" /> Quay lại trang chủ
          </Link>
        </div>
      </div>
    );
  }

  return (
    <main className="min-h-screen bg-black text-zinc-100 p-6 md:p-12 selection:bg-emerald-500/30 selection:text-white">
      {/* Header Navigation */}
      <div className="max-w-5xl mx-auto mb-8 flex justify-between items-center">
        <Link
          to="/"
          className="inline-flex items-center gap-2 text-sm text-zinc-400 hover:text-white font-semibold transition-colors group"
        >
          <ArrowLeft className="h-4 w-4 transform group-hover:-translate-x-1 transition-transform" />
          <span>Quay lại Console</span>
        </Link>

        <div className="flex items-center gap-3">
          <div className="px-3.5 py-1.5 rounded-full bg-zinc-900 border border-zinc-800 flex items-center gap-2 text-xs text-zinc-300">
            <div className="h-2 w-2 rounded-full bg-emerald-500 animate-pulse" />
            <span>Đã kết nối</span>
          </div>
          <button
            onClick={handleConnectWallet}
            className="inline-flex items-center gap-1.5 rounded-lg bg-zinc-900 hover:bg-zinc-800 border border-zinc-800 px-3 py-1.5 text-xs font-semibold text-zinc-300 hover:text-white transition-all cursor-pointer"
          >
            <Wallet className="h-3.5 w-3.5" />
            <span>Đổi ví</span>
          </button>
        </div>
      </div>

      {/* Main Container */}
      <div className="max-w-5xl mx-auto grid grid-cols-1 md:grid-cols-3 gap-8">
        {/* Sidebar Info Card */}
        <div className="md:col-span-1 space-y-6">
          <div className="rounded-3xl border border-zinc-800 bg-zinc-900/30 p-6 backdrop-blur-xl shadow-xl space-y-6">
            <div className="flex items-center gap-3.5">
              <div className="w-12 h-12 rounded-2xl bg-linear-to-tr from-emerald-500 to-teal-500 flex items-center justify-center shadow-lg">
                <Building className="h-6 w-6 text-black" />
              </div>
              <div>
                <span className="text-xs font-bold text-emerald-400 uppercase tracking-widest">
                  Chi nhánh
                </span>
                <h1 className="text-2xl font-black text-white leading-tight">
                  {branchInfo.name}
                </h1>
              </div>
            </div>

            <div className="space-y-4 pt-4 border-t border-zinc-800/80 text-sm">
              <div className="flex items-start gap-3">
                <Globe className="h-4.5 w-4.5 text-zinc-500 mt-0.5" />
                <div>
                  <div className="text-xs font-bold uppercase tracking-wide text-zinc-500">
                    Mã chi nhánh
                  </div>
                  <div className="font-mono text-zinc-300 mt-0.5 bg-zinc-950 px-2 py-0.5 rounded-md border border-zinc-850 inline-block">
                    {branchInfo.code}
                  </div>
                </div>
              </div>

              <div className="flex items-start gap-3">
                <MapPin className="h-4.5 w-4.5 text-zinc-500 mt-0.5" />
                <div>
                  <div className="text-xs font-bold uppercase tracking-wide text-zinc-500">
                    Địa chỉ
                  </div>
                  <div className="text-zinc-300 mt-0.5">
                    {branchInfo.organizationAddress || "N/A"}
                  </div>
                </div>
              </div>

              <div className="flex items-start gap-3">
                <Phone className="h-4.5 w-4.5 text-zinc-500 mt-0.5" />
                <div>
                  <div className="text-xs font-bold uppercase tracking-wide text-zinc-500">
                    Điện thoại
                  </div>
                  <div className="text-zinc-300 mt-0.5">
                    {branchInfo.phoneNumber || "N/A"}
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Contract Suite Details */}
        <div className="md:col-span-2 space-y-6">
          <div className="rounded-3xl border border-zinc-800 bg-zinc-900/10 p-6 md:p-8 backdrop-blur-lg shadow-xl">
            <h2 className="text-xl font-bold text-white mb-1.5 flex items-center gap-2">
              <Cpu className="h-5 w-5 text-emerald-400" />
              <span>Bộ Địa chỉ Hợp đồng (Contract Suite)</span>
            </h2>
            <p className="text-sm text-zinc-400 mb-8">
              Danh sách chi tiết toàn bộ địa chỉ hợp đồng quản lý, hợp đồng con,
              các factories và cấu trúc beacon.
            </p>

            {moduleAddresses ? (
              <div className="space-y-6">
                {/* 1. CORE SYSTEM CONTRACTS SECTION */}
                <div>
                  <h3 className="text-xs font-bold uppercase tracking-widest text-zinc-500 mb-3 border-b border-zinc-800 pb-2">
                    Core Platform & Managers
                  </h3>
                  <div className="space-y-3.5">
                    {/* Branch Module Manager */}
                    <div className="bg-zinc-900/40 rounded-xl border border-zinc-850 p-4.5 hover:border-zinc-850 transition-colors">
                      <div className="flex justify-between items-center mb-1">
                        <span className="text-xs font-bold uppercase tracking-wider text-zinc-400">
                          Branch Module Manager (Proxy)
                        </span>
                        <button
                          onClick={() =>
                            copyToClipboard(moduleAddresses.manager, "manager")
                          }
                          className="p-1 hover:bg-zinc-800 rounded text-zinc-500 hover:text-white transition-all cursor-pointer"
                        >
                          {copiedKey === "manager" ? (
                            <CheckCircle2 className="h-3.5 w-3.5 text-emerald-400" />
                          ) : (
                            <Copy className="h-3.5 w-3.5" />
                          )}
                        </button>
                      </div>
                      <div className="font-mono text-sm text-zinc-300 break-all select-all">
                        {moduleAddresses.manager}
                      </div>
                    </div>

                    {/* Staff Manager */}
                    <div className="bg-zinc-900/40 rounded-xl border border-zinc-850 p-4.5 hover:border-zinc-850 transition-colors">
                      <div className="flex justify-between items-center mb-1">
                        <span className="text-xs font-bold uppercase tracking-wider text-emerald-400">
                          Branch Staff Manager (Proxy)
                        </span>
                        <button
                          onClick={() =>
                            copyToClipboard(
                              moduleAddresses.staffManager,
                              "staffManager",
                            )
                          }
                          className="p-1 hover:bg-zinc-800 rounded text-zinc-500 hover:text-white transition-all cursor-pointer"
                        >
                          {copiedKey === "staffManager" ? (
                            <CheckCircle2 className="h-3.5 w-3.5 text-emerald-400" />
                          ) : (
                            <Copy className="h-3.5 w-3.5" />
                          )}
                        </button>
                      </div>
                      <div className="font-mono text-sm text-zinc-300 break-all select-all">
                        {moduleAddresses.staffManager}
                      </div>
                    </div>

                    {/* Staff Manager Beacon */}
                    <div className="bg-zinc-900/40 rounded-xl border border-zinc-850 p-4.5 hover:border-zinc-850 transition-colors">
                      <div className="flex justify-between items-center mb-1">
                        <span className="text-xs font-bold uppercase tracking-wider text-zinc-500">
                          Branch Staff Manager Beacon (Upgradeable)
                        </span>
                        <button
                          onClick={() =>
                            copyToClipboard(
                              moduleAddresses.staffManagerBeacon,
                              "staffManagerBeacon",
                            )
                          }
                          className="p-1 hover:bg-zinc-800 rounded text-zinc-500 hover:text-white transition-all cursor-pointer"
                        >
                          {copiedKey === "staffManagerBeacon" ? (
                            <CheckCircle2 className="h-3.5 w-3.5 text-emerald-400" />
                          ) : (
                            <Copy className="h-3.5 w-3.5" />
                          )}
                        </button>
                      </div>
                      <div className="font-mono text-sm text-zinc-300 break-all select-all">
                        {moduleAddresses.staffManagerBeacon}
                      </div>
                    </div>

                    {/* Module Registry */}
                    <div className="bg-zinc-900/40 rounded-xl border border-zinc-850 p-4.5 hover:border-zinc-850 transition-colors">
                      <div className="flex justify-between items-center mb-1">
                        <span className="text-xs font-bold uppercase tracking-wider text-zinc-500">
                          System Module Registry
                        </span>
                        <button
                          onClick={() =>
                            copyToClipboard(
                              moduleAddresses.moduleRegistry,
                              "moduleRegistry",
                            )
                          }
                          className="p-1 hover:bg-zinc-800 rounded text-zinc-500 hover:text-white transition-all cursor-pointer"
                        >
                          {copiedKey === "moduleRegistry" ? (
                            <CheckCircle2 className="h-3.5 w-3.5 text-emerald-400" />
                          ) : (
                            <Copy className="h-3.5 w-3.5" />
                          )}
                        </button>
                      </div>
                      <div className="font-mono text-sm text-zinc-300 break-all select-all">
                        {moduleAddresses.moduleRegistry}
                      </div>
                    </div>
                  </div>
                </div>

                {/* 2. MODULE INSTANCES & FACTORIES SECTION */}
                <div className="pt-4">
                  <h3 className="text-xs font-bold uppercase tracking-widest text-zinc-500 mb-3 border-b border-zinc-800 pb-2">
                    Module Implementations & Factories
                  </h3>
                  <div className="space-y-4">
                    {/* MEOS */}
                    <div className="bg-zinc-900/40 rounded-xl border border-zinc-850 p-5 hover:border-zinc-700/50 transition-all space-y-3">
                      <div>
                        <div className="flex justify-between items-center">
                          <span className="text-xs font-bold uppercase tracking-wider text-teal-400">
                            Module MEOS (Cyber Core Instance)
                          </span>
                          <button
                            onClick={() =>
                              copyToClipboard(moduleAddresses.meos, "meos")
                            }
                            className="p-1 hover:bg-zinc-800 rounded text-zinc-500 hover:text-white transition-all cursor-pointer"
                          >
                            {copiedKey === "meos" ? (
                              <CheckCircle2 className="h-3.5 w-3.5 text-emerald-400" />
                            ) : (
                              <Copy className="h-3.5 w-3.5" />
                            )}
                          </button>
                        </div>
                        <div className="font-mono text-sm text-zinc-300 mt-1 break-all select-all">
                          {moduleAddresses.meos ===
                          "0x0000000000000000000000000000000000000000" ? (
                            <span className="text-zinc-600 italic">
                              Chưa kích hoạt
                            </span>
                          ) : (
                            moduleAddresses.meos
                          )}
                        </div>
                      </div>

                      {/* MEOS Sub-contracts */}
                      {subContracts && moduleAddresses.meos !== "0x0000000000000000000000000000000000000000" && (
                        <div className="mt-3 pl-4 border-l-2 border-teal-500/30 space-y-2">
                          <div className="bg-zinc-950/50 rounded-lg p-3 border border-zinc-900/60">
                            <div className="flex justify-between items-center text-xs mb-1">
                              <span className="font-semibold text-zinc-400">PC Manager (Sub-contract)</span>
                              <button
                                onClick={() => copyToClipboard(subContracts.pcManager, "pcManager")}
                                className="hover:text-white cursor-pointer"
                              >
                                {copiedKey === "pcManager" ? (
                                  <CheckCircle2 className="h-3 w-3 text-emerald-400" />
                                ) : (
                                  <Copy className="h-3 w-3 text-zinc-500" />
                                )}
                              </button>
                            </div>
                            <div className="font-mono text-xs text-zinc-300 break-all">{subContracts.pcManager}</div>
                          </div>

                          <div className="bg-zinc-950/50 rounded-lg p-3 border border-zinc-900/60">
                            <div className="flex justify-between items-center text-xs mb-1">
                              <span className="font-semibold text-zinc-400">Account Manager (Sub-contract)</span>
                              <button
                                onClick={() => copyToClipboard(subContracts.accountManager, "accountManager")}
                                className="hover:text-white cursor-pointer"
                              >
                                {copiedKey === "accountManager" ? (
                                  <CheckCircle2 className="h-3 w-3 text-emerald-400" />
                                ) : (
                                  <Copy className="h-3 w-3 text-zinc-500" />
                                )}
                              </button>
                            </div>
                            <div className="font-mono text-xs text-zinc-300 break-all">{subContracts.accountManager}</div>
                          </div>
                        </div>
                      )}

                      <div className="pt-2 border-t border-zinc-850/60 flex justify-between items-center text-xs text-zinc-400">
                        <span>
                          Factory:{" "}
                          <span className="font-mono text-zinc-500">
                            {moduleAddresses.meosFactory}
                          </span>
                        </span>
                        <button
                          onClick={() =>
                            copyToClipboard(
                              moduleAddresses.meosFactory,
                              "meosFactory",
                            )
                          }
                          className="hover:text-white flex items-center gap-1 cursor-pointer"
                        >
                          <Copy className="h-3 w-3" />
                        </button>
                      </div>
                    </div>

                    {/* IQR */}
                    <div className="bg-zinc-900/40 rounded-xl border border-zinc-850 p-5 hover:border-zinc-700/50 transition-all space-y-3">
                      <div>
                        <div className="flex justify-between items-center">
                          <span className="text-xs font-bold uppercase tracking-wider text-cyan-400">
                            Module IQR (Internet Quality Registry Instance)
                          </span>
                          <button
                            onClick={() =>
                              copyToClipboard(moduleAddresses.iqr, "iqr")
                            }
                            className="p-1 hover:bg-zinc-800 rounded text-zinc-500 hover:text-white transition-all cursor-pointer"
                          >
                            {copiedKey === "iqr" ? (
                              <CheckCircle2 className="h-3.5 w-3.5 text-emerald-400" />
                            ) : (
                              <Copy className="h-3.5 w-3.5" />
                            )}
                          </button>
                        </div>
                        <div className="font-mono text-sm text-zinc-300 mt-1 break-all select-all">
                          {moduleAddresses.iqr ===
                          "0x0000000000000000000000000000000000000000" ? (
                            <span className="text-zinc-600 italic">
                              Chưa kích hoạt
                            </span>
                          ) : (
                            moduleAddresses.iqr
                          )}
                        </div>
                      </div>

                      {/* IQR Sub-contracts */}
                      {subContracts && moduleAddresses.iqr !== "0x0000000000000000000000000000000000000000" && (
                        <div className="mt-3 pl-4 border-l-2 border-cyan-500/30 space-y-2">
                          <div className="bg-zinc-950/50 rounded-lg p-3 border border-zinc-900/60">
                            <div className="flex justify-between items-center text-xs mb-1">
                              <span className="font-semibold text-zinc-400">POS Manager (Sub-contract)</span>
                              <button
                                onClick={() => copyToClipboard(subContracts.posManager, "posManager")}
                                className="hover:text-white cursor-pointer"
                              >
                                {copiedKey === "posManager" ? (
                                  <CheckCircle2 className="h-3 w-3 text-emerald-400" />
                                ) : (
                                  <Copy className="h-3 w-3 text-zinc-500" />
                                )}
                              </button>
                            </div>
                            <div className="font-mono text-xs text-zinc-300 break-all">{subContracts.posManager}</div>
                          </div>
                        </div>
                      )}

                      <div className="pt-2 border-t border-zinc-850/60 flex justify-between items-center text-xs text-zinc-400">
                        <span>
                          Factory:{" "}
                          <span className="font-mono text-zinc-500">
                            {moduleAddresses.iqrFactory}
                          </span>
                        </span>
                        <button
                          onClick={() =>
                            copyToClipboard(
                              moduleAddresses.iqrFactory,
                              "iqrFactory",
                            )
                          }
                          className="hover:text-white flex items-center gap-1 cursor-pointer"
                        >
                          <Copy className="h-3 w-3" />
                        </button>
                      </div>
                    </div>

                    {/* LOYALTY */}
                    <div className="bg-zinc-900/40 rounded-xl border border-zinc-850 p-5 hover:border-zinc-700/50 transition-all space-y-3">
                      <div>
                        <div className="flex justify-between items-center">
                          <span className="text-xs font-bold uppercase tracking-wider text-purple-400">
                            Module Loyalty (Rewards Instance)
                          </span>
                          <button
                            onClick={() =>
                              copyToClipboard(
                                moduleAddresses.loyalty,
                                "loyalty",
                              )
                            }
                            className="p-1 hover:bg-zinc-800 rounded text-zinc-500 hover:text-white transition-all cursor-pointer"
                          >
                            {copiedKey === "loyalty" ? (
                              <CheckCircle2 className="h-3.5 w-3.5 text-emerald-400" />
                            ) : (
                              <Copy className="h-3.5 w-3.5" />
                            )}
                          </button>
                        </div>
                        <div className="font-mono text-sm text-zinc-300 mt-1 break-all select-all">
                          {moduleAddresses.loyalty ===
                          "0x0000000000000000000000000000000000000000" ? (
                            <span className="text-zinc-600 italic">
                              Chưa kích hoạt
                            </span>
                          ) : (
                            moduleAddresses.loyalty
                          )}
                        </div>
                      </div>

                      {/* Loyalty Sub-contracts */}
                      {subContracts && moduleAddresses.loyalty !== "0x0000000000000000000000000000000000000000" && (
                        <div className="mt-3 pl-4 border-l-2 border-purple-500/30 space-y-2">
                          <div className="bg-zinc-950/50 rounded-lg p-3 border border-zinc-900/60">
                            <div className="flex justify-between items-center text-xs mb-1">
                              <span className="font-semibold text-zinc-400">Point Manager (Sub-contract)</span>
                              <button
                                onClick={() => copyToClipboard(subContracts.pointManager, "pointManager")}
                                className="hover:text-white cursor-pointer"
                              >
                                {copiedKey === "pointManager" ? (
                                  <CheckCircle2 className="h-3 w-3 text-emerald-400" />
                                ) : (
                                  <Copy className="h-3 w-3 text-zinc-500" />
                                )}
                              </button>
                            </div>
                            <div className="font-mono text-xs text-zinc-300 break-all">{subContracts.pointManager}</div>
                          </div>
                        </div>
                      )}

                      <div className="pt-2 border-t border-zinc-850/60 flex justify-between items-center text-xs text-zinc-400">
                        <span>
                          Factory:{" "}
                          <span className="font-mono text-zinc-500">
                            {moduleAddresses.loyaltyFactory}
                          </span>
                        </span>
                        <button
                          onClick={() =>
                            copyToClipboard(
                              moduleAddresses.loyaltyFactory,
                              "loyaltyFactory",
                            )
                          }
                          className="hover:text-white flex items-center gap-1 cursor-pointer"
                        >
                          <Copy className="h-3 w-3" />
                        </button>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            ) : (
              <div className="flex justify-center py-12">
                <Loader2 className="h-6 w-6 animate-spin text-emerald-500" />
              </div>
            )}
          </div>
        </div>
      </div>
    </main>
  );
}
