import React, { useState, useMemo } from "react";
import { motion, AnimatePresence } from "framer-motion";
import {
  X,
  Shirt,
  Flame,
  Check,
  Scissors,
  Hand,
  ShieldAlert,
  Zap,
} from "lucide-react";
import { fetchNui } from "../utils/fetchNui";
import type { WearingState, DripState, StealItem } from "../types";

interface Hotspot {
  id: string;
  label: string;
  top: string;
  left: string;
}

interface MannequinProps {
  activeCategory: string | null;
  wearing?: WearingState;
  sex?: 0 | 1;
  drip?: DripState;
  wearableProps?: boolean;
  hairToggled?: boolean;
  hairToggleable?: boolean;
  stealMode?: boolean;
  stealItems?: StealItem[];
  onCategoryClick: (id: string, rect: { left: number; top: number }) => void;
  onClose: () => void;
}

export default function Mannequin({
  activeCategory,
  wearing = { Drawables: {}, Props: {} },
  sex = 0,
  drip = { xp: 0, rate: 0, level: "Freshman", levelIndex: 1, progress: 0 },
  wearableProps = false,
  hairToggled = false,
  hairToggleable = false,
  stealMode = false,
  stealItems = [],
  onCategoryClick,
  onClose,
}: MannequinProps) {
  const [showDripPanel, setShowDripPanel] = useState(false);
  const [selectedToSteal, setSelectedToSteal] = useState<Set<string>>(
    new Set(),
  );

  // All possible hotspots
  const allHotspots: Hotspot[] = [
    { id: "head", label: "Testa", top: "12%", left: "50%" },
    { id: "torso", label: "Torso", top: "27%", left: "50%" },
    { id: "armor", label: "Kevlar", top: "35%", left: "50%" },
    { id: "bags", label: "Zaini", top: "25%", left: "60%" },
    { id: "accessories", label: "Accessori", top: "50%", left: "33%" },
    { id: "legs", label: "Pantaloni", top: "65%", left: "50%" },
    { id: "feet", label: "Scarpe", top: "88%", left: "50%" },
  ];

  // Map stealType/slotIndex to Hotspot ID
  const getHotspotForStealItem = (item: StealItem): string | null => {
    if (item.stealType === "torso") return "torso";
    if (item.stealType === "drawable") {
      if (item.slotIndex === 1) return "head";
      if (item.slotIndex === 8 || item.slotIndex === 11 || item.slotIndex === 3)
        return "torso";
      if (item.slotIndex === 9) return "armor";
      if (item.slotIndex === 5) return "bags";
      if (item.slotIndex === 4) return "legs";
      if (item.slotIndex === 6) return "feet";
      if (item.slotIndex === 7) return "accessories";
    }
    if (item.stealType === "prop") {
      if (item.slotIndex === 0 || item.slotIndex === 1 || item.slotIndex === 2)
        return "head";
      if (item.slotIndex === 6 || item.slotIndex === 7) return "accessories";
    }
    return null;
  };

  // Filter hotspots based on mode
  const visibleHotspots = useMemo(() => {
    if (!stealMode) {
      return allHotspots.filter((h) => {
        if (h.id === "armor" || h.id === "bags") return wearableProps;
        return true;
      });
    }
    // In steal mode, only show hotspots that have matching items to loot
    const activeHotspotIds = new Set(
      stealItems.map(getHotspotForStealItem).filter((id) => id !== null),
    );
    return allHotspots.filter((h) => activeHotspotIds.has(h.id));
  }, [stealMode, stealItems, wearableProps]);

  const toggleStealSelection = (spotId: string) => {
    setSelectedToSteal((prev) => {
      const next = new Set(prev);
      if (next.has(spotId)) next.delete(spotId);
      else next.add(spotId);
      return next;
    });
  };

  const handleStealAll = () => {
    const allIds = visibleHotspots.map((h) => h.id);
    setSelectedToSteal(new Set(allIds));
  };

  const handleConfirmSteal = () => {
    const itemsToSteal = stealItems.filter((item) => {
      const spotId = getHotspotForStealItem(item);
      return spotId && selectedToSteal.has(spotId);
    });
    fetchNui("confirmSteal", { items: itemsToSteal }).catch(() => {});
    onClose();
  };

  const handleClick = (
    e: React.MouseEvent<HTMLButtonElement>,
    spotId: string,
  ) => {
    if (stealMode) {
      toggleStealSelection(spotId);
      return;
    }
    const rect = e.currentTarget.getBoundingClientRect();
    const centerX = rect.left + rect.width / 2;
    const centerY = rect.top + rect.height / 2;
    onCategoryClick(spotId, { left: centerX, top: centerY });
  };

  const normalNavItems = [
    {
      icon: <Shirt size={20} />,
      id: "clothes",
      active: !showDripPanel,
      onClick: () => setShowDripPanel(false),
    },
    {
      icon: <Flame size={20} />,
      id: "drip",
      active: showDripPanel,
      onClick: () => {
        setShowDripPanel(!showDripPanel);
        if (!showDripPanel) onCategoryClick("", { left: 0, top: 0 });
      },
    },
    {
      icon: <Scissors size={20} />,
      id: "hair",
      active: hairToggleable,
      onClick: () => {
        fetchNui("handleHairToggle").catch(() => {});
      },
    },
    { icon: <X size={20} />, id: "close", active: false, onClick: onClose },
  ];

  const stealNavItems = [
    {
      icon: <Zap size={20} />,
      id: "stealAll",
      label: "RUBA TUTTO",
      active:
        selectedToSteal.size === visibleHotspots.length &&
        visibleHotspots.length > 0,
      onClick: handleStealAll,
      className:
        "bg-red-600 hover:bg-red-500 text-white px-6 w-auto rounded-full gap-2 text-[11px] font-black tracking-widest",
    },
    {
      icon: <Hand size={20} />,
      id: "confirm",
      label: "PRELEVA",
      active: selectedToSteal.size > 0,
      onClick: handleConfirmSteal,
      disabled: selectedToSteal.size === 0,
      className:
        selectedToSteal.size > 0
          ? "bg-gradient-to-br from-orange-500 to-red-600 text-white px-6 w-auto rounded-full gap-2 text-[11px] font-black tracking-widest shadow-[0_0_20px_rgba(239,68,68,0.4)]"
          : "bg-white/5 text-white/20 border border-white/5 px-6 w-auto rounded-full gap-2 text-[11px] font-black tracking-widest cursor-not-allowed",
    },
    { icon: <X size={20} />, id: "close", active: false, onClick: onClose },
  ];

  const navItems = stealMode ? stealNavItems : (normalNavItems as any[]);

  return (
    <motion.div
      initial={{ x: 200, opacity: 0 }}
      animate={{ x: 0, opacity: 1 }}
      exit={{ x: 200, opacity: 0 }}
      transition={{ type: "spring", stiffness: 200, damping: 25 }}
      className="absolute inset-0 flex items-center justify-end pr-[0vw] pointer-events-none"
    >
      <div className="relative h-[55vh] aspect-square flex justify-center pointer-events-auto">
        {/* Header for Steal Mode */}
        {stealMode && (
          <motion.div
            initial={{ opacity: 0, y: -20 }}
            animate={{ opacity: 1, y: -40 }}
            className="absolute top-0 left-1/2 -translate-x-1/2 whitespace-nowrap z-30 flex flex-col items-center gap-2"
          >
            <div className="flex items-center gap-3 px-6 py-2 bg-red-600/20 backdrop-blur-xl border border-red-500/30 rounded-full shadow-[0_0_30px_rgba(239,68,68,0.2)]">
              <ShieldAlert size={18} className="text-red-500 animate-pulse" />
              <span className="text-xs font-black text-white uppercase tracking-[0.3em]">
                SVALIGIAMENTO IN CORSO
              </span>
            </div>
          </motion.div>
        )}

        {/* 3D Mannequin Base Image */}
        <img
          key={sex === 1 ? "female" : "male"}
          src={sex === 1 ? "./mannequin_female.png" : "./mannequin.png"}
          alt="Ped Mannequin"
          className={`w-full h-full object-contain transition-all duration-500 z-10
            ${stealMode ? "sepia-[0.3] hue-rotate-[320deg] brightness-[0.8]" : "drop-shadow-[0_10px_50px_rgba(255,255,255,0.15)]"}`}
        />

        {/* Clothing Layers (Visual Overlays) */}
        <AnimatePresence>
          {wearing.Props?.["0"] && (
            <motion.img
              key="layer-hat"
              initial={{ opacity: 0, y: -10, scale: 0.9 }}
              animate={{ opacity: 1, y: 0, scale: 1 }}
              exit={{ opacity: 0, y: -10, scale: 0.9 }}
              transition={{ type: "spring", stiffness: 300, damping: 20 }}
              src="./layers/hat.png"
              className="absolute top-[-2%] left-[51%] w-[18%] h-auto -translate-x-1/2 z-20 pointer-events-none drop-shadow-[0_5px_15px_rgba(0,0,0,0.5)]"
              alt="Hat Layer"
            />
          )}
        </AnimatePresence>

        {/* Pedestal shadow effect - Restored to Minimalist Original */}
        <div className="absolute bottom-[0.5%] left-1/2 -translate-x-1/2 w-[55%] h-14 bg-gradient-to-t from-white/30 to-transparent rounded-[100%] blur-[8px] z-0 shadow-[0_25px_60px_rgba(255,255,255,0.2)] opacity-60" />

        {/* Interactive Hotspots */}
        {visibleHotspots.map((spot) => {
          const isActive = activeCategory === spot.id;
          const isSelected = stealMode && selectedToSteal.has(spot.id);
          const accentColor = stealMode
            ? isSelected
              ? "bg-red-500"
              : "bg-red-500/20"
            : "bg-blue-500/20";
          const borderColor = stealMode
            ? isSelected
              ? "border-red-400"
              : "border-red-500/40"
            : "border-blue-500/40";
          const dotColor = stealMode
            ? isSelected
              ? "#ef4444"
              : "#ffffff"
            : isActive
              ? "#3b82f6"
              : "#ffffff";

          return (
            <button
              key={spot.id}
              className="absolute z-20 w-12 h-12 flex items-center justify-center group cursor-pointer"
              style={{
                top: spot.top,
                left: spot.left,
                transform: "translate(-50%, -50%)",
              }}
              onClick={(e) => handleClick(e, spot.id)}
            >
              <motion.div
                animate={{
                  scale: isActive || isSelected ? [1, 1.4, 1] : [1, 1.1, 1],
                  opacity:
                    isActive || isSelected ? [0.4, 0.8, 0.4] : [0.1, 0.3, 0.1],
                }}
                transition={{
                  duration: 2,
                  repeat: Infinity,
                  ease: "easeInOut",
                }}
                className={`absolute rounded-full transition-all duration-300 ${accentColor} ${borderColor} border ${isActive || isSelected ? "w-12 h-12" : "w-10 h-10"}`}
              />
              <motion.div
                animate={{
                  scale: isActive || isSelected ? 1.5 : 1,
                  backgroundColor: dotColor,
                }}
                className={`z-10 w-3 h-3 rounded-full flex items-center justify-center shadow-[0_0_20px_rgba(255,255,255,0.8)] 
                  ${isActive || isSelected ? "shadow-[0_0_25px_rgba(239,68,68,1)]" : ""}`}
              >
                {stealMode && isSelected && (
                  <Check size={8} strokeWidth={4} className="text-white" />
                )}
              </motion.div>
              <div className="absolute top-1/2 left-full ml-5 -translate-y-1/2 opacity-0 group-hover:opacity-100 transition-all duration-300 transform translate-x-2 group-hover:translate-x-0 pointer-events-none whitespace-nowrap">
                <span
                  className={`px-3 py-1.5 text-[11px] font-bold text-white uppercase tracking-[0.25em] backdrop-blur-xl rounded-md border-l-4 shadow-2xl transition-colors
                  ${stealMode ? "bg-red-950/90 border-red-600" : "bg-[#0F172A]/90 border-blue-600"}`}
                >
                  {spot.label}
                </span>
              </div>
            </button>
          );
        })}

        {/* Floating Bottom Navbar */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          exit={{ opacity: 0, y: 20 }}
          transition={{
            type: "spring",
            stiffness: 220,
            damping: 25,
            delay: 0.05,
          }}
          className={`absolute -bottom-16 left-1/2 -translate-x-1/2 backdrop-blur-3xl border rounded-full flex flex-row items-center px-8 py-3 shadow-[0_20px_40px_rgba(0,0,0,0.9)] z-30 gap-6 transition-all duration-500
            ${stealMode ? "bg-red-950/60 border-red-500/30" : "bg-[#0F172A]/70 border-white/25"}`}
        >
          {navItems.map((item: any) => (
            <button
              key={item.id}
              onClick={item.onClick}
              disabled={item.disabled}
              className={`transition-all duration-300 relative group flex items-center justify-center h-10 rounded-full
                ${
                  item.className ||
                  (item.active
                    ? item.id === "drip"
                      ? "bg-gradient-to-br from-orange-500 to-red-500 text-white shadow-[0_0_20px_rgba(249,115,22,0.4)] w-10"
                      : item.id === "clothes"
                        ? "bg-gradient-to-br from-blue-600 to-indigo-700 text-white shadow-[0_0_20px_rgba(37,99,235,0.4)] w-10"
                        : item.id === "hair"
                          ? "bg-gradient-to-br from-cyan-500 to-teal-500 text-white shadow-[0_0_20px_rgba(6,182,212,0.4)] w-10"
                          : "bg-white text-black w-10"
                    : "text-white/50 hover:text-white hover:bg-white/10 w-10")
                }`}
            >
              <motion.div
                whileHover={{ scale: 1.1 }}
                className="flex items-center justify-center gap-2"
              >
                {React.cloneElement(item.icon as React.ReactElement<any>, {
                  size: 18,
                  strokeWidth: item.active ? 2.5 : 1.5,
                })}
                {stealMode && item.label && (
                  <span className="text-[11px] font-black tracking-widest">
                    {item.label}
                  </span>
                )}
              </motion.div>
            </button>
          ))}

          <AnimatePresence>
            {showDripPanel && !stealMode && (
              <motion.div
                initial={{ x: 50, opacity: 0 }}
                animate={{ x: 0, opacity: 1 }}
                exit={{ x: 50, opacity: 0 }}
                className="absolute top-full left-1/2 -translate-x-1/2 mt-4 pt-1 pointer-events-none"
              >
                <div className="backdrop-blur-3xl bg-[#0F172A]/75 border border-white/20 rounded-full px-6 py-2.5 flex items-center gap-6 shadow-[0_20px_40px_rgba(0,0,0,0.8)] pointer-events-auto border-t-white/10 whitespace-nowrap">
                  <div className="flex items-center gap-2 pr-6 border-r border-white/10">
                    <Flame
                      size={14}
                      className="text-orange-500 fill-orange-500/10 drop-shadow-[0_0_8px_rgba(249,115,22,0.4)]"
                    />
                    <span className="text-[11px] font-black text-white uppercase tracking-widest">
                      {drip.level}
                    </span>
                  </div>
                  <div className="w-32 h-1 bg-white/10 rounded-full overflow-hidden">
                    <motion.div
                      layoutId="drip-meter"
                      initial={{ width: 0 }}
                      animate={{
                        width: `${Math.min(drip.progress * 100, 100)}%`,
                      }}
                      className="h-full bg-orange-500 shadow-[0_0_10px_rgba(249,115,22,0.4)]"
                    />
                  </div>
                  <div className="flex items-center gap-4 pl-2">
                    <div className="flex items-baseline gap-1">
                      <span className="text-xs font-black text-white tabular-nums drop-shadow-sm leading-none">
                        {drip.xp}
                      </span>
                      <span className="text-[10px] font-bold text-orange-500 uppercase leading-none tracking-tighter">
                        XP
                      </span>
                      {drip.rate > 1 && (
                        <span className="text-[10px] font-black text-emerald-400 italic ml-1">
                          x{drip.rate}
                        </span>
                      )}
                    </div>
                    <div className="bg-white/10 px-2 py-0.5 rounded border border-white/5 backdrop-blur-md">
                      <span className="text-[10px] font-black text-white/60 tracking-widest leading-none">
                        LV.{drip.levelIndex}
                      </span>
                    </div>
                  </div>
                </div>
              </motion.div>
            )}
          </AnimatePresence>
        </motion.div>
      </div>
    </motion.div>
  );
}
