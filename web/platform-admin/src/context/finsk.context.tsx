import {
  createContext,
  useContext,
  useEffect,
  useState,
  type PropsWithChildren,
} from "react";
import { FiaiSDK } from "@metanodejs/fiai-sdk";

interface FinsdkContextType {
  loadingSdk: boolean;
}

const FinsdkContext = createContext<FinsdkContextType | null>(null);

type FinsdkProviderProps = PropsWithChildren;

const FinsdkProvider: React.FC<FinsdkProviderProps> = ({ children }) => {
  const [loadingSdk, setLoadingSdk] = useState<boolean>(true);

  useEffect(() => {
    const handleIntSDK = async () => {
      try {
        await FiaiSDK.init({});
      } catch (error) {
        console.log("error", error);
      } finally {
        setLoadingSdk(false);
      }
    };

    void handleIntSDK();
  }, []);

  if (loadingSdk) {
    return (
      <div className="flex h-screen w-full flex-col items-center justify-center bg-[#09090B] text-white relative overflow-hidden select-none">
        {/* Glowing ambient background spots */}
        <div className="absolute top-1/4 left-1/4 w-72 h-72 bg-emerald-500/5 blur-[120px] rounded-full pointer-events-none" />
        <div className="absolute bottom-1/4 right-1/4 w-72 h-72 bg-blue-500/5 blur-[120px] rounded-full pointer-events-none" />

        <div className="flex w-80 flex-col items-center gap-6 rounded-3xl bg-white/3 border border-white/5 p-8 shadow-2xl backdrop-blur-2xl relative z-10">
          <div className="relative flex h-16 w-16 items-center justify-center">
            <div className="absolute h-full w-full animate-spin rounded-full border-2 border-white/5 border-t-emerald-500 border-r-emerald-500/40"></div>
            <div className="absolute h-8 w-8 animate-pulse rounded-full bg-emerald-500/10 border border-emerald-500/20"></div>
          </div>

          <div className="flex w-full flex-col items-center gap-2 text-center">
            <h3 className="text-base font-semibold text-zinc-100 tracking-wide animate-pulse">
              loading…
            </h3>
          </div>
        </div>
      </div>
    );
  }
  return (
    <FinsdkContext.Provider value={{ loadingSdk }}>
      {children}
    </FinsdkContext.Provider>
  );
};

const useFinsdkContext = () => {
  const context = useContext(FinsdkContext);
  if (!context)
    throw new Error("useFinsdkContext must be used within FinsdkProvider");
  return context;
};

// eslint-disable-next-line react-refresh/only-export-components
export { FinsdkProvider, useFinsdkContext };
