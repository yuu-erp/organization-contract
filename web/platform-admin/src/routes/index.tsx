import { connectWallet, getActiveWallet } from "@metanodejs/system-core";
import { createFileRoute, Link } from "@tanstack/react-router";
import {
  createColumnHelper,
  flexRender,
  getCoreRowModel,
  useReactTable,
} from "@tanstack/react-table";
import {
  Building,
  FolderPlus,
  Loader2,
  MapPin,
  Phone,
  Plus,
  ShieldAlert,
  User,
  Wallet,
  Edit3,
  ChevronDown,
  ChevronRight,
} from "lucide-react";
import { useEffect, useMemo, useState } from "react";
import { contractManager } from "../contracts/contract-manager";
import type {
  FullOrganizationInfo,
  FullBranchInfo,
} from "../contracts/organization-reader/organization-reader.contract";
import { MODULE_KEYS, MODULE_INFO, getModuleLabel } from "../constants/modules";

export const Route = createFileRoute("/")({ component: App });

function App() {
  const [walletAddress, setWalletAddress] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [isPlatformAdmin, setIsPlatformAdmin] = useState(false);
  const [organizations, setOrganizations] = useState<FullOrganizationInfo[]>(
    [],
  );
  const [refreshTrigger, setRefreshTrigger] = useState(0);

  // Tree Expansion states
  const [expandedOrgIds, setExpandedOrgIds] = useState<Record<number, boolean>>(
    {},
  );
  const [orgBranches, setOrgBranches] = useState<
    Record<number, FullBranchInfo[]>
  >({});

  const toggleExpandOrg = async (orgId: number) => {
    const isCurrentlyExpanded = !!expandedOrgIds[orgId];
    setExpandedOrgIds((prev) => ({ ...prev, [orgId]: !isCurrentlyExpanded }));

    if (!isCurrentlyExpanded && !orgBranches[orgId]) {
      try {
        const branches =
          await contractManager.organizationReader.getOrganizationBranchesFull(
            orgId,
          );
        setOrgBranches((prev) => ({ ...prev, [orgId]: branches }));
      } catch (err) {
        console.error(
          `Failed to fetch branches for organization #${orgId}`,
          err,
        );
      }
    }
  };

  // Modals state
  const [showCreateOrg, setShowCreateOrg] = useState(false);
  const [showCreateBranch, setShowCreateBranch] = useState(false);
  const [showEditOrg, setShowEditOrg] = useState(false);
  const [selectedOrgId, setSelectedOrgId] = useState<number | null>(null);

  // Form states
  const [editForm, setEditForm] = useState({
    name: "",
    address: "",
    phone: "",
  });
  const [orgForm, setOrgForm] = useState({
    owner: "",
    name: "",
    address: "",
    phone: "",
  });
  const [branchForm, setBranchForm] = useState({
    name: "",
    address: "",
    phone: "",
    code: "",
  });

  const [selectedModules, setSelectedModules] = useState<string[]>([]);
  const [availableModules, setAvailableModules] = useState<
    { key: string; name: string }[]
  >([]);
  const [branchModules, setBranchModules] = useState<string[]>([]);

  const [formSubmitting, setFormSubmitting] = useState(false);

  // Auto-generate random metadata for forms when modal opens
  useEffect(() => {
    if (showCreateOrg) {
      const randomId = Math.floor(100 + Math.random() * 900);
      const randomOwner =
        "0x" +
        Array.from(
          { length: 40 },
          () => "0123456789abcdef"[Math.floor(Math.random() * 16)],
        ).join("");
      setOrgForm({
        owner: randomOwner,
        name: `Cyber Arena ${randomId}`,
        address: `${Math.floor(10 + Math.random() * 490)} Điện Biên Phủ, Quận 1, TP.HCM`,
        phone: `+849${Math.floor(10000000 + Math.random() * 90000000)}`,
      });
      setSelectedModules([
        MODULE_KEYS.MODULE_MEOS,
        MODULE_KEYS.MODULE_IQR,
        MODULE_KEYS.MODULE_LOYALTY,
      ]);
    }
  }, [showCreateOrg]);

  useEffect(() => {
    if (showCreateBranch) {
      const randomId = Math.floor(10 + Math.random() * 90);
      setBranchForm({
        code: `branch_q${randomId}`,
        name: `Chi nhánh Quận ${randomId}`,
        address: `${Math.floor(10 + Math.random() * 490)} Điện Biên Phủ, Quận ${randomId}, TP.HCM`,
        phone: `+849${Math.floor(10000000 + Math.random() * 90000000)}`,
      });
    }
  }, [showCreateBranch]);

  // 1. Check wallet connection and role
  useEffect(() => {
    const initWallet = async () => {
      try {
        const wallet = await getActiveWallet();
        if (wallet && wallet.address) {
          setWalletAddress(wallet.address);
          contractManager.init(wallet.address);

          // Verify Platform Admin Role
          const isAdmin =
            await contractManager.systemAccessControl.isPlatformAdmin(
              wallet.address,
            );

          console.log("isAdmin", isAdmin);
          setIsPlatformAdmin(isAdmin);
        }
      } catch (err) {
        console.error("Wallet initialization failed", err);
      } finally {
        setLoading(false);
      }
    };
    initWallet();
  }, []);

  // 2. Fetch Organizations list
  useEffect(() => {
    if (!walletAddress || !isPlatformAdmin) return;

    const fetchOrgs = async () => {
      try {
        const count =
          await contractManager.organizationManager.organizationCounter();
        const list: FullOrganizationInfo[] = [];
        for (let i = 1; i <= count; i++) {
          try {
            const org =
              await contractManager.organizationReader.getFullOrganizationInfo(
                i,
              );
            if (org.exists) {
              list.push(org);
            }
          } catch (e) {
            console.error(`Failed to fetch org ${i}`, e);
          }
        }
        setOrganizations(list);
      } catch (err) {
        console.error("Failed to fetch organizations", err);
      }
    };

    fetchOrgs();
  }, [walletAddress, isPlatformAdmin, refreshTrigger]);

  const handleConnectWallet = async () => {
    setLoading(true);
    try {
      const wallet = await connectWallet();
      if (wallet && wallet.address) {
        setWalletAddress(wallet.address);
        contractManager.init(wallet.address);
        const isAdmin =
          await contractManager.systemAccessControl.isPlatformAdmin(
            wallet.address,
          );
        setIsPlatformAdmin(isAdmin);
      }
    } catch (err) {
      console.error("Failed to connect wallet", err);
    } finally {
      setLoading(false);
    }
  };

  // 3. Create Organization
  const handleCreateOrg = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!orgForm.owner || !orgForm.name) return;

    setFormSubmitting(true);
    try {
      // Step 1: Deploy Organization Core (Write transaction)
      await contractManager.organizationManager.createOrganization(
        orgForm.owner,
        selectedModules,
      );

      // Step 2: Fetch the newly created Organization ID by owner
      const orgId =
        await contractManager.organizationManager.getOrganizationIdByOwner(
          orgForm.owner,
        );

      if (orgId === 0) {
        throw new Error("Không tìm thấy Organization ID vừa tạo.");
      }

      // Step 3: Register Metadata
      await contractManager.organizationMetadataRegistry.setOrganizationMetadata(
        orgId,
        orgForm.name,
        orgForm.address,
        orgForm.phone,
      );

      setShowCreateOrg(false);
      setOrgForm({ owner: "", name: "", address: "", phone: "" });
      setSelectedModules([]);
      setRefreshTrigger((prev) => prev + 1);
    } catch (err) {
      console.error("Failed to create organization", err);
      alert("Triển khai thất bại. Vui lòng kiểm tra lại quyền.");
    } finally {
      setFormSubmitting(false);
    }
  };

  // 4. Create Branch
  const handleCreateBranch = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedOrgId || !branchForm.name || !branchForm.code) return;

    setFormSubmitting(true);
    try {
      console.log("branchModules: ", branchModules);
      // Step 1: Create Branch Core (Write transaction)
      await contractManager.organizationManager.createBranch(
        selectedOrgId,
        branchModules,
      );

      // Step 2: Fetch the newly created Branch ID using branchCounter
      const branchId =
        await contractManager.organizationManager.branchCounter();

      if (branchId === 0) {
        throw new Error("Không lấy được Branch ID.");
      }

      // Step 3: Register Branch Metadata
      await contractManager.organizationMetadataRegistry.setBranchMetadata(
        branchId,
        branchForm.name,
        branchForm.address,
        branchForm.phone,
        branchForm.code,
      );

      setShowCreateBranch(false);
      setBranchForm({ name: "", address: "", phone: "", code: "" });
      setBranchModules([]);

      if (selectedOrgId !== null) {
        setOrgBranches((prev) => {
          const updated = { ...prev };
          delete updated[selectedOrgId];
          return updated;
        });
      }

      setRefreshTrigger((prev) => prev + 1);
    } catch (err) {
      console.error("Failed to create branch", err);
      alert("Triển khai chi nhánh thất bại.");
    } finally {
      setFormSubmitting(false);
    }
  };

  // 5. Edit Organization Metadata
  const handleEditOrg = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedOrgId || !editForm.name) return;

    setFormSubmitting(true);
    try {
      await contractManager.organizationMetadataRegistry.setOrganizationMetadata(
        selectedOrgId,
        editForm.name,
        editForm.address,
        editForm.phone,
      );

      setShowEditOrg(false);
      setRefreshTrigger((prev) => prev + 1);
    } catch (err) {
      console.error("Failed to edit organization metadata", err);
      alert("Cập nhật thông tin thất bại.");
    } finally {
      setFormSubmitting(false);
    }
  };

  // TanStack Table setup
  const columnHelper = createColumnHelper<FullOrganizationInfo>();
  const columns = useMemo(
    () => [
      columnHelper.accessor("id", {
        header: "ID",
        cell: (info) => {
          const orgId = info.getValue();
          const isExpanded = !!expandedOrgIds[orgId];
          return (
            <button
              onClick={(e) => {
                e.stopPropagation();
                toggleExpandOrg(orgId);
              }}
              className="flex items-center gap-2 font-semibold text-emerald-500 hover:text-emerald-400 cursor-pointer text-left focus:outline-none"
            >
              {isExpanded ? (
                <ChevronDown className="h-4 w-4 text-zinc-400" />
              ) : (
                <ChevronRight className="h-4 w-4 text-zinc-400" />
              )}
              <span>#{orgId}</span>
            </button>
          );
        },
      }),
      columnHelper.accessor("name", {
        header: "Tổ chức",
        cell: (info) => (
          <div>
            <div className="font-semibold text-zinc-100">
              {info.getValue() || "Chưa đặt tên"}
            </div>
            <div className="text-xs text-zinc-500 flex items-center gap-1 mt-0.5">
              <Building className="h-3 w-3" /> Org Profile
            </div>
          </div>
        ),
      }),
      columnHelper.accessor("organizationAddress", {
        header: "Địa chỉ",
        cell: (info) => (
          <div className="flex items-center gap-1.5 text-zinc-300 text-sm max-w-xs truncate">
            <MapPin className="h-4 w-4 text-zinc-500 shrink-0" />
            <span>{info.getValue() || "N/A"}</span>
          </div>
        ),
      }),
      columnHelper.accessor("phoneNumber", {
        header: "Số điện thoại",
        cell: (info) => (
          <div className="flex items-center gap-1.5 text-zinc-300 text-sm">
            <Phone className="h-4 w-4 text-zinc-500 shrink-0" />
            <span>{info.getValue() || "N/A"}</span>
          </div>
        ),
      }),
      columnHelper.accessor("owner", {
        header: "Owner",
        cell: (info) => (
          <div className="flex items-center gap-1.5 text-zinc-400 font-mono text-xs">
            <User className="h-3.5 w-3.5 text-zinc-600 shrink-0" />
            <span>
              {info.getValue().slice(0, 6)}...{info.getValue().slice(-4)}
            </span>
          </div>
        ),
      }),
      columnHelper.display({
        id: "actions",
        header: "Hành động",
        cell: (info) => {
          const org = info.row.original;
          return (
            <div className="flex items-center gap-2">
              <button
                onClick={async () => {
                  setSelectedOrgId(org.id);
                  setShowCreateBranch(true);
                  try {
                    console.log("Fetching modules for Org ID:", org.id);
                    const { keys } =
                      await contractManager.moduleRegistry.getOrgModules(
                        org.id,
                      );
                    console.log("Keys returned from getOrgModules:", keys);
                    const modulesList = keys.map((k: string) => ({
                      key: k,
                      name: getModuleLabel(k),
                    }));
                    console.log("Processed modulesList for UI:", modulesList);
                    setAvailableModules(modulesList);
                    setBranchModules([]);
                  } catch (err) {
                    console.error("Failed to load org modules", err);
                    alert(
                      "Lỗi khi tải modules của tổ chức: " +
                        (err as Error).message,
                    );
                  }
                }}
                className="inline-flex items-center gap-1.5 rounded-lg bg-emerald-500/10 border border-emerald-500/20 px-3 py-1.5 text-xs font-semibold text-emerald-400 hover:bg-emerald-500/20 transition-all cursor-pointer"
              >
                <FolderPlus className="h-3.5 w-3.5" />
                <span>Thêm chi nhánh</span>
              </button>
              <button
                onClick={() => {
                  setSelectedOrgId(org.id);
                  setEditForm({
                    name: org.name || "",
                    address: org.organizationAddress || "",
                    phone: org.phoneNumber || "",
                  });
                  setShowEditOrg(true);
                }}
                className="inline-flex items-center gap-1.5 rounded-lg bg-zinc-800 border border-zinc-700 px-3 py-1.5 text-xs font-semibold text-zinc-300 hover:bg-zinc-700 hover:text-white transition-all cursor-pointer"
              >
                <Edit3 className="h-3.5 w-3.5" />
                <span>Sửa thông tin</span>
              </button>
            </div>
          );
        },
      }),
    ],
    [],
  );

  const table = useReactTable({
    data: organizations,
    columns,
    getCoreRowModel: getCoreRowModel(),
  });

  if (loading) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-[#09090B] text-white">
        <div className="flex flex-col items-center gap-3">
          <Loader2 className="h-10 w-10 animate-spin text-emerald-500" />
          <span className="text-zinc-400 font-medium">
            Đang tải cấu hình ví...
          </span>
        </div>
      </div>
    );
  }

  if (!walletAddress) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-[#09090B] text-white px-4">
        <div className="max-w-md w-full rounded-4xl bg-zinc-900/50 border border-zinc-800 p-8 text-center shadow-2xl backdrop-blur-xl relative overflow-hidden">
          <div className="absolute top-0 left-0 w-full h-1.5 bg-linear-to-r from-emerald-500 to-teal-500" />
          <Wallet className="h-16 w-16 text-zinc-600 mx-auto mb-6" />
          <h2 className="text-2xl font-bold text-zinc-100 mb-2">
            Kết nối ví để quản trị
          </h2>
          <p className="text-zinc-400 text-sm mb-6 leading-relaxed">
            Hệ thống quản lý chuỗi phòng máy MetaNode yêu cầu bạn kết nối tài
            khoản quản trị viên tối cao (Platform Admin).
          </p>
          <button
            onClick={handleConnectWallet}
            className="w-full inline-flex items-center justify-center gap-2 rounded-xl bg-linear-to-r from-emerald-500 to-teal-500 px-6 py-3 font-semibold text-black hover:opacity-95 transition-all shadow-[0_8px_24px_rgba(16,185,129,0.2)] cursor-pointer"
          >
            <Wallet className="h-5 w-5" />
            <span>Kết nối ví MetaNode</span>
          </button>
        </div>
      </div>
    );
  }

  if (!isPlatformAdmin) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-[#09090B] text-white px-4">
        <div className="max-w-md w-full rounded-4xl bg-zinc-900/50 border border-red-900/20 p-8 text-center shadow-2xl backdrop-blur-xl relative overflow-hidden">
          <div className="absolute top-0 left-0 w-full h-1.5 bg-red-500" />
          <ShieldAlert className="h-16 w-16 text-red-500/80 mx-auto mb-6" />
          <h2 className="text-2xl font-bold text-red-400 mb-2">
            Quyền truy cập bị từ chối
          </h2>
          <p className="text-zinc-400 text-sm mb-6 leading-relaxed">
            Tài khoản ví của bạn (
            <span className="font-mono text-zinc-300">
              {walletAddress.slice(0, 6)}...{walletAddress.slice(-4)}
            </span>
            ) không phải là quản trị viên của hệ thống.
          </p>
          <div className="text-xs text-zinc-500 bg-red-950/20 border border-red-900/20 rounded-xl p-3 mb-6">
            Nếu bạn là chủ sở hữu, hãy phân quyền PLATFORM_ADMIN_ROLE trong
            SystemAccessControl.
          </div>
          <button
            onClick={handleConnectWallet}
            className="w-full inline-flex items-center justify-center gap-2 rounded-xl bg-zinc-800 border border-zinc-700 px-6 py-3 font-semibold text-zinc-300 hover:text-white transition-all cursor-pointer"
          >
            <Wallet className="h-5 w-5" />
            <span>Đổi ví kết nối</span>
          </button>
        </div>
      </div>
    );
  }

  return (
    <main className="min-h-screen bg-[#09090B] text-zinc-100 px-4 py-8 sm:px-6 lg:px-8">
      <div className="max-w-7xl mx-auto space-y-8">
        {/* Upper Header */}
        <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 border-b border-zinc-800 pb-6">
          <div>
            <span className="text-xs font-semibold uppercase tracking-wider text-emerald-400">
              Hệ thống quản trị
            </span>
            <h1 className="text-3xl font-extrabold text-white mt-1">
              Platform Console
            </h1>
          </div>

          <button
            onClick={() => setShowCreateOrg(true)}
            className="inline-flex items-center gap-2 rounded-xl bg-linear-to-r from-emerald-500 to-teal-500 px-4 py-2.5 text-sm font-semibold text-black hover:opacity-95 transition-all shadow-[0_4px_16px_rgba(16,185,129,0.15)] cursor-pointer"
          >
            <Plus className="h-4 w-4 text-black stroke-[3px]" />
            <span>Thêm tổ chức mới</span>
          </button>
        </div>

        {/* Dashboard statistics */}
        <div className="grid gap-4 grid-cols-1 sm:grid-cols-3">
          <div className="rounded-2xl border border-zinc-800 bg-zinc-900/30 p-6 backdrop-blur-xl">
            <span className="text-sm font-medium text-zinc-400">
              Tổng số Tổ chức
            </span>
            <h3 className="text-3xl font-bold text-white mt-2">
              {organizations.length}
            </h3>
          </div>
          <div className="rounded-2xl border border-zinc-800 bg-zinc-900/30 p-6 backdrop-blur-xl">
            <span className="text-sm font-medium text-zinc-400">
              Trạng thái hệ thống
            </span>
            <div className="flex items-center gap-2 mt-3">
              <span className="h-2.5 w-2.5 rounded-full bg-emerald-500 animate-pulse" />
              <span className="text-sm font-semibold text-emerald-400">
                Hoạt động bình thường
              </span>
            </div>
          </div>
          <div className="rounded-2xl border border-zinc-800 bg-zinc-900/30 p-6 backdrop-blur-xl flex flex-col justify-between">
            <div>
              <span className="text-sm font-medium text-zinc-400">
                Ví đang kết nối
              </span>
              <div
                className="text-sm font-mono text-zinc-300 mt-2 truncate"
                title={walletAddress}
              >
                {walletAddress}
              </div>
            </div>
            <button
              onClick={handleConnectWallet}
              className="mt-3 w-full inline-flex items-center justify-center gap-1.5 rounded-xl border border-zinc-750 bg-zinc-800/40 py-2 text-xs font-semibold text-zinc-300 hover:bg-zinc-800 hover:text-white transition-all cursor-pointer"
            >
              <Wallet className="h-3.5 w-3.5" />
              <span>Đổi ví kết nối</span>
            </button>
          </div>
        </div>

        {/* Organizations Table Card */}
        <div className="rounded-3xl border border-zinc-800 bg-zinc-900/20 overflow-hidden shadow-2xl backdrop-blur-lg">
          <div className="px-6 py-5 border-b border-zinc-800 flex justify-between items-center bg-zinc-900/30">
            <h3 className="text-lg font-bold text-white">
              Danh sách tổ chức (Client Organizations)
            </h3>
          </div>

          <div className="overflow-x-auto">
            {organizations.length === 0 ? (
              <div className="py-20 text-center text-zinc-500">
                <Building className="h-12 w-12 mx-auto mb-4 text-zinc-700" />
                <p className="text-base">
                  Không có tổ chức nào được tìm thấy trên hệ thống.
                </p>
                <p className="text-xs text-zinc-600 mt-1">
                  Hãy bắt đầu bằng cách click nút thêm tổ chức mới.
                </p>
              </div>
            ) : (
              <table className="w-full text-left border-collapse">
                <thead>
                  {table.getHeaderGroups().map((headerGroup) => (
                    <tr
                      key={headerGroup.id}
                      className="border-b border-zinc-800 bg-zinc-900/40"
                    >
                      {headerGroup.headers.map((header) => (
                        <th
                          key={header.id}
                          className="px-6 py-4 text-xs font-bold uppercase tracking-wider text-zinc-400"
                        >
                          {flexRender(
                            header.column.columnDef.header,
                            header.getContext(),
                          )}
                        </th>
                      ))}
                    </tr>
                  ))}
                </thead>
                <tbody className="divide-y divide-zinc-800/60">
                  {table.getRowModel().rows.map((row) => {
                    const org = row.original;
                    const isExpanded = !!expandedOrgIds[org.id];
                    const branches = orgBranches[org.id] || [];
                    return (
                      <optgroup
                        key={org.id}
                        label={org.name || `Org #${org.id}`}
                        className="contents"
                      >
                        <tr className="hover:bg-zinc-850/50 transition-colors">
                          {row.getVisibleCells().map((cell) => (
                            <td
                              key={cell.id}
                              className="px-6 py-4.5 whitespace-nowrap text-sm"
                            >
                              {flexRender(
                                cell.column.columnDef.cell,
                                cell.getContext(),
                              )}
                            </td>
                          ))}
                        </tr>
                        {isExpanded && (
                          <tr className="bg-zinc-950/60">
                            <td
                              colSpan={columns.length}
                              className="px-8 py-6 border-l-2 border-emerald-500"
                            >
                              <div className="space-y-4">
                                <div className="text-xs font-bold uppercase tracking-wider text-emerald-400/90 flex items-center gap-2">
                                  <div className="h-1.5 w-1.5 rounded-full bg-emerald-400" />
                                  <span>
                                    Danh sách Chi nhánh ({branches.length})
                                  </span>
                                </div>
                                {branches.length === 0 ? (
                                  <div className="text-xs text-zinc-500 italic py-2 pl-4">
                                    Chưa có chi nhánh nào được thiết lập cho tổ
                                    chức này.
                                  </div>
                                ) : (
                                  <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 pl-4">
                                    {branches.map((branch) => (
                                      <Link
                                        key={branch.id}
                                        // @ts-ignore
                                        to={`/branch/${branch.id}`}
                                        className="block p-4.5 rounded-2xl border border-zinc-800 bg-zinc-900/40 hover:bg-zinc-900/80 hover:border-emerald-500/30 transition-all cursor-pointer group shadow-xs hover:shadow-[0_4px_20px_rgba(16,185,129,0.05)]"
                                      >
                                        <div className="flex justify-between items-start mb-2.5">
                                          <span className="font-semibold text-zinc-200 group-hover:text-white transition-colors text-sm">
                                            {branch.name}
                                          </span>
                                          <span className="text-[10px] font-mono font-bold uppercase tracking-widest text-zinc-400 bg-zinc-800 px-2 py-0.5 rounded-md border border-zinc-700">
                                            {branch.code}
                                          </span>
                                        </div>
                                        <div className="text-xs text-zinc-400 flex items-center gap-2 mt-3.5">
                                          <MapPin className="h-3.5 w-3.5 text-zinc-500 shrink-0" />
                                          <span className="truncate">
                                            {branch.organizationAddress ||
                                              "N/A"}
                                          </span>
                                        </div>
                                        <div className="text-xs text-zinc-400 flex items-center gap-2 mt-1.5">
                                          <Phone className="h-3.5 w-3.5 text-zinc-500 shrink-0" />
                                          <span>
                                            {branch.phoneNumber || "N/A"}
                                          </span>
                                        </div>
                                      </Link>
                                    ))}
                                  </div>
                                )}
                              </div>
                            </td>
                          </tr>
                        )}
                      </optgroup>
                    );
                  })}
                </tbody>
              </table>
            )}
          </div>
        </div>
      </div>

      {/* Modal: Create Organization */}
      {showCreateOrg && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm">
          <div className="bg-zinc-900 border border-zinc-800 rounded-3xl max-w-lg w-full overflow-hidden shadow-2xl relative">
            <div className="p-6 border-b border-zinc-800 bg-zinc-900/60 flex justify-between items-center">
              <h3 className="text-xl font-bold text-white">Thêm tổ chức mới</h3>
              <button
                onClick={() => setShowCreateOrg(false)}
                className="text-zinc-400 hover:text-white transition-colors cursor-pointer text-2xl font-light"
              >
                &times;
              </button>
            </div>

            <form onSubmit={handleCreateOrg} className="p-6 space-y-4">
              <div>
                <label className="block text-xs font-bold uppercase tracking-wider text-zinc-400 mb-1.5">
                  Địa chỉ ví Owner
                </label>
                <input
                  type="text"
                  required
                  placeholder="0x..."
                  value={orgForm.owner}
                  onChange={(e) =>
                    setOrgForm({ ...orgForm, owner: e.target.value })
                  }
                  className="w-full rounded-xl bg-zinc-950 border border-zinc-800 px-4 py-2.5 text-zinc-100 focus:outline-none focus:border-emerald-500 font-mono text-sm"
                />
              </div>

              <div>
                <label className="block text-xs font-bold uppercase tracking-wider text-zinc-400 mb-1.5">
                  Tên tổ chức
                </label>
                <input
                  type="text"
                  required
                  placeholder="Ví dụ: Net Cafe Station"
                  value={orgForm.name}
                  onChange={(e) =>
                    setOrgForm({ ...orgForm, name: e.target.value })
                  }
                  className="w-full rounded-xl bg-zinc-950 border border-zinc-800 px-4 py-2.5 text-zinc-100 focus:outline-none focus:border-emerald-500 text-sm"
                />
              </div>

              <div>
                <label className="block text-xs font-bold uppercase tracking-wider text-zinc-400 mb-1.5">
                  Địa chỉ Trụ sở
                </label>
                <input
                  type="text"
                  placeholder="Ví dụ: 47 Điện Biên Phủ, Q1, TP.HCM"
                  value={orgForm.address}
                  onChange={(e) =>
                    setOrgForm({ ...orgForm, address: e.target.value })
                  }
                  className="w-full rounded-xl bg-zinc-950 border border-zinc-800 px-4 py-2.5 text-zinc-100 focus:outline-none focus:border-emerald-500 text-sm"
                />
              </div>

              <div>
                <label className="block text-xs font-bold uppercase tracking-wider text-zinc-400 mb-1.5">
                  Số điện thoại liên hệ
                </label>
                <input
                  type="text"
                  placeholder="Ví dụ: +84333..."
                  value={orgForm.phone}
                  onChange={(e) =>
                    setOrgForm({ ...orgForm, phone: e.target.value })
                  }
                  className="w-full rounded-xl bg-zinc-950 border border-zinc-800 px-4 py-2.5 text-zinc-100 focus:outline-none focus:border-emerald-500 text-sm"
                />
              </div>

              <div>
                <label className="block text-xs font-bold uppercase tracking-wider text-zinc-400 mb-2">
                  Cấp quyền sở hữu Modules
                </label>
                <div className="space-y-2.5">
                  {MODULE_INFO.map((mod) => (
                    <label
                      key={mod.key}
                      className="flex items-center gap-3 px-4 py-3 rounded-xl bg-zinc-950 border border-zinc-850 hover:border-zinc-800 cursor-pointer select-none transition-colors"
                    >
                      <input
                        type="checkbox"
                        checked={selectedModules.includes(mod.key)}
                        onChange={(e) => {
                          if (e.target.checked) {
                            setSelectedModules([...selectedModules, mod.key]);
                          } else {
                            setSelectedModules(
                              selectedModules.filter((k) => k !== mod.key),
                            );
                          }
                        }}
                        className="rounded border-zinc-800 bg-zinc-900 text-emerald-500 focus:ring-emerald-500/20 h-4.5 w-4.5"
                      />
                      <span className="text-zinc-300 text-sm font-semibold">
                        {mod.label}
                      </span>
                    </label>
                  ))}
                </div>
              </div>

              <div className="pt-4 flex gap-3">
                <button
                  type="button"
                  onClick={() => setShowCreateOrg(false)}
                  className="flex-1 py-3 rounded-xl bg-zinc-850 hover:bg-zinc-800 border border-zinc-800 font-semibold text-zinc-300 transition-all cursor-pointer text-sm"
                >
                  Hủy bỏ
                </button>
                <button
                  type="submit"
                  disabled={formSubmitting}
                  className="flex-1 py-3 rounded-xl bg-linear-to-r from-emerald-500 to-teal-500 font-semibold text-black hover:opacity-95 transition-all shadow-[0_4px_16px_rgba(16,185,129,0.15)] flex justify-center items-center gap-2 cursor-pointer text-sm"
                >
                  {formSubmitting ? (
                    <>
                      <Loader2 className="h-4 w-4 animate-spin" />
                      <span>Đang tạo...</span>
                    </>
                  ) : (
                    <span>Tạo mới</span>
                  )}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Modal: Create Branch */}
      {showCreateBranch && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm">
          <div className="bg-zinc-900 border border-zinc-800 rounded-3xl max-w-lg w-full overflow-hidden shadow-2xl relative">
            <div className="p-6 border-b border-zinc-800 bg-zinc-900/60 flex justify-between items-center">
              <h3 className="text-xl font-bold text-white">Thêm chi nhánh</h3>
              <button
                onClick={() => setShowCreateBranch(false)}
                className="text-zinc-400 hover:text-white transition-colors cursor-pointer text-2xl font-light"
              >
                &times;
              </button>
            </div>

            <form onSubmit={handleCreateBranch} className="p-6 space-y-4">
              <div>
                <label className="block text-xs font-bold uppercase tracking-wider text-zinc-400 mb-1.5">
                  Mã chi nhánh (Branch Code)
                </label>
                <input
                  type="text"
                  required
                  placeholder="Ví dụ: branch_q1"
                  value={branchForm.code}
                  onChange={(e) =>
                    setBranchForm({ ...branchForm, code: e.target.value })
                  }
                  className="w-full rounded-xl bg-zinc-950 border border-zinc-800 px-4 py-2.5 text-zinc-100 focus:outline-none focus:border-emerald-500 font-mono text-sm"
                />
              </div>

              <div>
                <label className="block text-xs font-bold uppercase tracking-wider text-zinc-400 mb-1.5">
                  Tên chi nhánh
                </label>
                <input
                  type="text"
                  required
                  placeholder="Ví dụ: Chi nhánh Quận 1"
                  value={branchForm.name}
                  onChange={(e) =>
                    setBranchForm({ ...branchForm, name: e.target.value })
                  }
                  className="w-full rounded-xl bg-zinc-950 border border-zinc-800 px-4 py-2.5 text-zinc-100 focus:outline-none focus:border-emerald-500 text-sm"
                />
              </div>

              <div>
                <label className="block text-xs font-bold uppercase tracking-wider text-zinc-400 mb-1.5">
                  Địa chỉ Chi nhánh
                </label>
                <input
                  type="text"
                  placeholder="Ví dụ: 47 Điện Biên Phủ, Q1, TP.HCM"
                  value={branchForm.address}
                  onChange={(e) =>
                    setBranchForm({ ...branchForm, address: e.target.value })
                  }
                  className="w-full rounded-xl bg-zinc-950 border border-zinc-800 px-4 py-2.5 text-zinc-100 focus:outline-none focus:border-emerald-500 text-sm"
                />
              </div>

              <div>
                <label className="block text-xs font-bold uppercase tracking-wider text-zinc-400 mb-1.5">
                  Số điện thoại liên hệ
                </label>
                <input
                  type="text"
                  placeholder="Ví dụ: +84333..."
                  value={branchForm.phone}
                  onChange={(e) =>
                    setBranchForm({ ...branchForm, phone: e.target.value })
                  }
                  className="w-full rounded-xl bg-zinc-950 border border-zinc-800 px-4 py-2.5 text-zinc-100 focus:outline-none focus:border-emerald-500 text-sm"
                />
              </div>

              <div>
                <label className="block text-xs font-bold uppercase tracking-wider text-zinc-400 mb-2">
                  Kích hoạt Modules (Chỉ chọn từ module Tổ chức sở hữu)
                </label>
                {availableModules.length === 0 ? (
                  <div className="text-xs text-zinc-500 italic py-2 pl-2">
                    Tổ chức này chưa được cấp quyền sở hữu bất kỳ module nào.
                  </div>
                ) : (
                  <div className="space-y-2.5">
                    {availableModules.map((mod) => (
                      <label
                        key={mod.key}
                        className="flex items-center justify-between px-4 py-3 rounded-xl bg-zinc-950 border border-zinc-850 hover:border-zinc-800 cursor-pointer select-none transition-colors"
                      >
                        <span className="text-zinc-300 text-sm font-semibold">
                          {mod.name}
                        </span>
                        <input
                          type="checkbox"
                          checked={branchModules.includes(mod.key)}
                          onChange={(e) => {
                            if (e.target.checked) {
                              setBranchModules([...branchModules, mod.key]);
                            } else {
                              setBranchModules(
                                branchModules.filter((k) => k !== mod.key),
                              );
                            }
                          }}
                          className="rounded border-zinc-800 bg-zinc-900 text-emerald-500 focus:ring-emerald-500/20 h-4.5 w-4.5"
                        />
                      </label>
                    ))}
                  </div>
                )}
              </div>

              <div className="pt-4 flex gap-3">
                <button
                  type="button"
                  onClick={() => setShowCreateBranch(false)}
                  className="flex-1 py-3 rounded-xl bg-zinc-850 hover:bg-zinc-800 border border-zinc-800 font-semibold text-zinc-300 transition-all cursor-pointer text-sm"
                >
                  Hủy bỏ
                </button>
                <button
                  type="submit"
                  disabled={formSubmitting}
                  className="flex-1 py-3 rounded-xl bg-linear-to-r from-emerald-500 to-teal-500 font-semibold text-black hover:opacity-95 transition-all shadow-[0_4px_16px_rgba(16,185,129,0.15)] flex justify-center items-center gap-2 cursor-pointer text-sm"
                >
                  {formSubmitting ? (
                    <>
                      <Loader2 className="h-4 w-4 animate-spin" />
                      <span>Đang tạo...</span>
                    </>
                  ) : (
                    <span>Tạo mới</span>
                  )}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Modal: Edit Organization */}
      {showEditOrg && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/60 backdrop-blur-sm">
          <div className="bg-zinc-900 border border-zinc-800 rounded-3xl max-w-lg w-full overflow-hidden shadow-2xl relative">
            <div className="p-6 border-b border-zinc-800 bg-zinc-900/60 flex justify-between items-center">
              <h3 className="text-xl font-bold text-white">
                Chỉnh sửa thông tin
              </h3>
              <button
                onClick={() => setShowEditOrg(false)}
                className="text-zinc-400 hover:text-white transition-colors cursor-pointer text-2xl font-light"
              >
                &times;
              </button>
            </div>

            <form onSubmit={handleEditOrg} className="p-6 space-y-4">
              <div>
                <label className="block text-xs font-bold uppercase tracking-wider text-zinc-400 mb-1.5">
                  Tên tổ chức
                </label>
                <input
                  type="text"
                  required
                  placeholder="Ví dụ: Net Cafe Station"
                  value={editForm.name}
                  onChange={(e) =>
                    setEditForm({ ...editForm, name: e.target.value })
                  }
                  className="w-full rounded-xl bg-zinc-950 border border-zinc-800 px-4 py-2.5 text-zinc-100 focus:outline-none focus:border-emerald-500 text-sm"
                />
              </div>

              <div>
                <label className="block text-xs font-bold uppercase tracking-wider text-zinc-400 mb-1.5">
                  Địa chỉ Trụ sở
                </label>
                <input
                  type="text"
                  placeholder="Ví dụ: 47 Điện Biên Phủ, Q1, TP.HCM"
                  value={editForm.address}
                  onChange={(e) =>
                    setEditForm({ ...editForm, address: e.target.value })
                  }
                  className="w-full rounded-xl bg-zinc-950 border border-zinc-800 px-4 py-2.5 text-zinc-100 focus:outline-none focus:border-emerald-500 text-sm"
                />
              </div>

              <div>
                <label className="block text-xs font-bold uppercase tracking-wider text-zinc-400 mb-1.5">
                  Số điện thoại liên hệ
                </label>
                <input
                  type="text"
                  placeholder="Ví dụ: +84333..."
                  value={editForm.phone}
                  onChange={(e) =>
                    setEditForm({ ...editForm, phone: e.target.value })
                  }
                  className="w-full rounded-xl bg-zinc-950 border border-zinc-800 px-4 py-2.5 text-zinc-100 focus:outline-none focus:border-emerald-500 text-sm"
                />
              </div>

              <div className="pt-4 flex gap-3">
                <button
                  type="button"
                  onClick={() => setShowEditOrg(false)}
                  className="flex-1 py-3 rounded-xl bg-zinc-850 hover:bg-zinc-800 border border-zinc-800 font-semibold text-zinc-300 transition-all cursor-pointer text-sm"
                >
                  Hủy bỏ
                </button>
                <button
                  type="submit"
                  disabled={formSubmitting}
                  className="flex-1 py-3 rounded-xl bg-linear-to-r from-emerald-500 to-teal-500 font-semibold text-black hover:opacity-95 transition-all shadow-[0_4px_16px_rgba(16,185,129,0.15)] flex justify-center items-center gap-2 cursor-pointer text-sm"
                >
                  {formSubmitting ? (
                    <>
                      <Loader2 className="h-4 w-4 animate-spin" />
                      <span>Đang lưu...</span>
                    </>
                  ) : (
                    <span>Lưu thay đổi</span>
                  )}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </main>
  );
}
