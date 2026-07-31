import React, { useState, useMemo, useEffect } from "react";
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
import {
  DRAWABLE_SLOTS,
  DRAWABLE_SLOTS_WEARABLE,
  PROP_SLOTS,
  LAYER_META,
} from "../constants";
import type {
  WearingState,
  DripState,
  StealItem,
  UILabels,
} from "../types";

interface Hotspot {
  id: string;
  label: string;
  top: string;
  left: string;
}

const HOTSPOT_TO_LAYERS: Record<string, string[]> = {
  head: ["Props-0", "Props-1", "Props-2", "Drawables-1"],
  torso: ["Drawables-3", "Drawables-8", "Drawables-11"],
  armor: ["Drawables-9"],
  bags: ["Drawables-5"],
  legs: ["Drawables-4"],
  feet: ["Drawables-6"],
  accessories: ["Drawables-7", "Props-6", "Props-7"],
};

const HOVER_LAYER_FILTER =
  "drop-shadow(0 0 5px rgba(var(--mbt-accent-rgb),0.2))";
const ACTIVE_LAYER_FILTER =
  "drop-shadow(0 0 7px rgba(var(--mbt-accent-rgb),0.45))";

let pedestalWarmed = false;


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
  // Usa la logica centrale di App per capire se uno slot è indossato.
  // Necessaria per mask/bag/armor che non stanno nella wearing table ma in extraState.
  isSlotWorn?: (slotType: "Drawables" | "Props", slotIndex: number) => boolean;
  // Dizionario UI dal Lua. Se non è ancora arrivato valgono i fallback inline
  // definiti più sotto, uno per hotspot.
  labels?: UILabels;
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
  isSlotWorn,
  labels,
  onCategoryClick,
  onClose,
}: MannequinProps) {
  const [showDripPanel, setShowDripPanel] = useState(false);
  const [selectedToSteal, setSelectedToSteal] = useState<Set<string>>(
    new Set(),
  );
  const [hoveredSlot, setHoveredSlot] = useState<string | null>(null);

  // Warm the pedestal once during an idle period. Later menu openings reuse
  // that readiness instead of starting another delayed compositor workload.
  const [pedestalReady, setPedestalReady] = useState(pedestalWarmed);
  useEffect(() => {
    if (pedestalWarmed) return;

    const reveal = () => {
      pedestalWarmed = true;
      setPedestalReady(true);
    };
    if (typeof window.requestIdleCallback === "function") {
      const handle = window.requestIdleCallback(reveal, { timeout: 900 });
      return () => window.cancelIdleCallback(handle);
    }

    const handle = window.setTimeout(reveal, 700);
    return () => window.clearTimeout(handle);
  }, []);

  const hotspotLabels = labels?.hotspots;
  const allHotspots: Hotspot[] = [
    { id: "head", label: hotspotLabels?.head ?? "Head & Face", top: "12%", left: "50%" },
    { id: "torso", label: hotspotLabels?.torso ?? "Torso", top: "27%", left: "50%" },
    { id: "armor", label: hotspotLabels?.armor ?? "Body Armor", top: "35%", left: "50%" },
    { id: "bags", label: hotspotLabels?.bags ?? "Bags", top: "25%", left: "60%" },
    { id: "accessories", label: hotspotLabels?.accessories ?? "Accessories", top: "50%", left: "33%" },
    { id: "legs", label: hotspotLabels?.legs ?? "Pants", top: "65%", left: "50%" },
    { id: "feet", label: hotspotLabels?.feet ?? "Shoes", top: "88%", left: "50%" },
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
      label: labels?.steal?.stealAll ?? "STEAL ALL",
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
      label: labels?.steal?.collect ?? "COLLECT",
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
      transition={{ duration: 0.24, ease: [0.22, 1, 0.36, 1] }}
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
            <div className="flex items-center gap-3 px-6 py-2 bg-red-950/80 border border-red-500/40 rounded-full shadow-[0_0_30px_rgba(239,68,68,0.3)]">
              <ShieldAlert size={18} className="text-red-500 animate-pulse" />
              <span className="text-xs font-black text-white uppercase tracking-[0.3em]">
                {labels?.steal?.lootingInProgress ?? "LOOTING IN PROGRESS"}
              </span>
            </div>
          </motion.div>
        )}

        {/* Immagine base del mannequin */}
        <div className="absolute inset-0 z-0 flex items-center justify-center pointer-events-none" />

        <img
          key={sex === 1 ? "female" : "male"}
          src={sex === 1 ? "./mannequin_female.png" : "./mannequin_male.png"}
          alt="Ped Mannequin"
          className={`w-full h-full object-contain transition-all duration-500 z-10
            ${stealMode ? "sepia-[0.3] hue-rotate-[320deg] brightness-[0.8]" : ""}`}
        />

        {/* Clothing Layers (Visual Overlays).
            initial={false} → i capi già indossati alla prima apertura UI
            appaiono istantaneamente (niente flash). Solo i capi aggiunti/
            rimossi DOPO (dress/undress con UI aperta) animano con bloom. */}
        <AnimatePresence initial={false}>
          {Object.entries(LAYER_META).map(([key, meta]) => {
            const [slotType, slotIndexStr] = key.split("-");
            // Usa isSlotWorn se disponibile (gestisce mask/bag/armor da extraState),
            // fallback al check diretto su wearing per compatibilità.
            const worn = isSlotWorn
              ? isSlotWorn(
                  slotType as "Drawables" | "Props",
                  Number(slotIndexStr),
                )
              : wearing[slotType as keyof typeof wearing]?.[slotIndexStr];
            if (!worn) return null;
            const gender = sex === 1 ? "female" : "male";
            if (!meta.availableFor.includes(gender)) return null;
            const isLayerHovered =
              hoveredSlot !== null &&
              (HOTSPOT_TO_LAYERS[hoveredSlot] || []).includes(key);
            // Lo slot attivo riceve un overlay di glow separato, così l'opacità
            // si anima senza ricalcolare il filtro a ogni frame.
            const isLayerActive =
              activeCategory !== null &&
              (HOTSPOT_TO_LAYERS[activeCategory] || []).includes(key);
            // Ombra sotto il capo per farlo "poggiare", rim light bianca in alto
            // per staccarlo dal fondo, glow d'accento se lo slot è in hover.
            // Il filtro resta assente durante l'entrata del mannequin: rasterizzare
            // un'ombra grande per ogni layer trasparente costa una comparsa ritardata.
            const layerFilter = isLayerHovered
              ? HOVER_LAYER_FILTER
              : undefined;
            const layerSrc = `./layers/${meta.path}_${gender}.png`;
            return (
              // Bloom solo in uscita: con la UI aperta il player non si veste,
              // quindi un bloom in entrata non si vedrebbe mai.
              //
              // Il colore è un HEX e non var(--mbt-accent): framer-motion non
              // parsa le parentesi nested dentro drop-shadow. È l'unico colore
              // della UI che non segue MBT.Theme, e va allineato a mano.
              <motion.div
                key={`layer-${key}`}
                // Niente filter in initial/animate: crearlo al primo paint
                // forza il browser a creare un GPU compositing layer, che
                // ha un costo visibile come "comparsa ritardata" del capo
                // rispetto al mannequin. Filter solo nell'exit (bloom
                // undress) dove è l'utente a innescare l'animazione e il
                // costo di creazione si maschera nella transizione.
                initial={{ opacity: 0, scale: 0.95, x: "-50%" }}
                animate={{ opacity: 1, scale: 1, x: "-50%" }}
                exit={{
                  opacity: 0,
                  scale: 0.85,
                  x: "-50%",
                  filter: "drop-shadow(0 0 18px #00e676dd)",
                }}
                transition={{ duration: 0.35, ease: "easeOut" }}
                style={{
                  top: meta.top,
                  left: meta.left,
                  width: meta.width,
                  zIndex: meta.zIndex,
                }}
                className="absolute h-auto pointer-events-none"
              >
                <img
                  src={layerSrc}
                  style={{ filter: layerFilter }}
                  className="w-full h-auto block transition-[filter] duration-200 ease-out"
                  alt={`${meta.path} layer`}
                />
                {isLayerActive && (
                  <img
                    src={layerSrc}
                    style={{ filter: ACTIVE_LAYER_FILTER }}
                    className="absolute inset-0 w-full h-auto block mbt-layer-glow pointer-events-none"
                    alt=""
                    aria-hidden="true"
                  />
                )}
              </motion.div>
            );
          })}
        </AnimatePresence>

        {/* Piedistallo: glow ambientale + anelli scanner. Il primo mount aspetta
            un periodo di idle; le aperture successive riusano lo stato scaldato. */}
        {pedestalReady && (
          <>
            {/* Layer 1: luce radiale d'ambiente che respira. */}
            <div
              className="absolute bottom-0 left-1/2 -translate-x-1/2 w-[65%] h-24 mbt-pedestal-breath pointer-events-none z-0"
              style={{
                background:
                  "radial-gradient(ellipse at 50% 100%, rgba(var(--mbt-accent-rgb),0.25) 0%, rgba(255,255,255,0.15) 35%, transparent 70%)",
              }}
            />

            {/* Layer 2: disco di base (l'ombra "fisica" sotto i piedi) */}
            <div
              className="absolute bottom-[0.5%] left-1/2 -translate-x-1/2 w-[42%] h-6 rounded-[100%] blur-[6px] opacity-60 pointer-events-none z-0"
              style={{
                background:
                  "radial-gradient(ellipse at center, rgba(var(--mbt-accent-rgb),0.5) 0%, transparent 70%)",
              }}
            />

            {/* Layer 3: scanner ring 1.
                Wrapper esterno: posizionamento statico. Inner: solo scale. */}
            <div className="absolute bottom-[2%] left-1/2 -translate-x-1/2 w-[38%] h-4 pointer-events-none z-0">
              <div
                className="w-full h-full rounded-[100%] border border-[rgba(var(--mbt-accent-rgb),0.6)] mbt-scanner-ring"
                style={{
                  boxShadow: "0 0 12px rgba(var(--mbt-accent-rgb),0.45)",
                }}
              />
            </div>

            {/* Layer 4: scanner ring 2 — sfasato nel tempo per continuità */}
            <div className="absolute bottom-[2%] left-1/2 -translate-x-1/2 w-[38%] h-4 pointer-events-none z-0">
              <div
                className="w-full h-full rounded-[100%] border border-[rgba(var(--mbt-accent-rgb),0.5)] mbt-scanner-ring-delay"
                style={{
                  boxShadow: "0 0 12px rgba(var(--mbt-accent-rgb),0.4)",
                }}
              />
            </div>
          </>
        )}

        {/* Interactive Hotspots */}
        {visibleHotspots.map((spot) => {
          const isActive = activeCategory === spot.id;
          const isSelected = stealMode && selectedToSteal.has(spot.id);
          // Step A: lo slot è "occupato" se almeno uno dei layer mappati a
          // questo hotspot è indossato. Usato per ridurre l'opacità del dot
          // (l'item stesso è già segnale di "qui c'è qualcosa" — il dot
          // serve di più sugli slot vuoti come CTA "qui puoi mettere qualcosa")
          const hotspotLayers = HOTSPOT_TO_LAYERS[spot.id] || [];
          const isOccupied =
            !stealMode &&
            hotspotLayers.some((layerKey) => {
              const [slotType, slotIndexStr] = layerKey.split("-");
              return isSlotWorn
                ? isSlotWorn(
                    slotType as "Drawables" | "Props",
                    Number(slotIndexStr),
                  )
                : !!wearing[slotType as keyof typeof wearing]?.[slotIndexStr];
            });
          // Dim solo se occupato E non attivo (non voglio nascondere lo slot
          // su cui l'utente ha cliccato). Hover restaura full via Tailwind.
          const isDimmed = isOccupied && !isActive;
          const accentColor = stealMode
            ? isSelected
              ? "bg-red-500"
              : "bg-red-500/20"
            : "bg-[rgba(var(--mbt-accent-rgb),0.2)]";
          const borderColor = stealMode
            ? isSelected
              ? "border-red-400"
              : "border-red-500/40"
            : "border-[rgba(var(--mbt-accent-rgb),0.4)]";
          const dotColor = stealMode
            ? isSelected
              ? "#ef4444"
              : "#ffffff"
            : isActive
              ? "var(--mbt-accent)"
              : "#ffffff";

          return (
            <button
              key={spot.id}
              className={`absolute z-20 w-12 h-12 flex items-center justify-center group cursor-pointer transition-opacity duration-300 ${
                isDimmed ? "opacity-30 hover:opacity-100" : "opacity-100"
              }`}
              style={{
                top: spot.top,
                left: spot.left,
                transform: "translate(-50%, -50%)",
              }}
              onClick={(e) => handleClick(e, spot.id)}
              onMouseEnter={() => setHoveredSlot(spot.id)}
              onMouseLeave={() => setHoveredSlot(null)}
            >
              <div
                className={`absolute rounded-full transition-[width,height,background-color,border-color] duration-300 ${accentColor} ${borderColor} border ${
                  isActive || isSelected
                    ? "w-12 h-12 mbt-hotspot-pulse-active"
                    : "w-10 h-10 mbt-hotspot-pulse-idle"
                }`}
              />
              <div
                style={{ backgroundColor: dotColor }}
                className={`z-10 w-3 h-3 rounded-full flex items-center justify-center shadow-[0_0_20px_rgba(255,255,255,0.8)] transition-[transform,background-color] duration-200
                  ${isActive || isSelected ? "scale-150 shadow-[0_0_25px_rgba(239,68,68,1)]" : "scale-100"}`}
              >
                {stealMode && isSelected && (
                  <Check size={8} strokeWidth={4} className="text-white" />
                )}
              </div>
              <div className="absolute top-1/2 left-full ml-5 -translate-y-1/2 opacity-0 group-hover:opacity-100 transition-all duration-300 transform translate-x-2 group-hover:translate-x-0 pointer-events-none whitespace-nowrap">
                <span
                  className={`px-3 py-1.5 text-[11px] font-bold text-white uppercase tracking-[0.25em] rounded-md border-l-4 shadow-2xl transition-colors drop-shadow-[0_2px_12px_rgba(0,0,0,1)]
                  ${stealMode ? "bg-red-950 border-red-600" : "bg-[#0F172A] border-[var(--mbt-accent)]"}`}
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
          className={`absolute -bottom-16 left-1/2 -translate-x-1/2 border rounded-full flex flex-row items-center px-8 py-3 shadow-[0_20px_40px_rgba(0,0,0,0.9)] z-30 gap-6 transition-all duration-500
            ${stealMode ? "bg-red-950 border-red-500/30" : "bg-[#0F172A]/95 border-white/25"}`}
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
                        ? "bg-gradient-to-br from-[var(--mbt-accent-dark)] to-[var(--mbt-accent-deep)] text-white shadow-[0_0_20px_rgba(var(--mbt-accent-rgb),0.4)] w-10"
                        : item.id === "hair"
                          ? "bg-gradient-to-br from-[var(--mbt-accent-dark)] to-[var(--mbt-accent-deep)] text-white shadow-[0_0_20px_rgba(var(--mbt-accent-rgb),0.3)] w-10 opacity-80"
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
                initial={{ y: -10, opacity: 0 }}
                animate={{ y: 0, opacity: 1 }}
                exit={{ y: -10, opacity: 0 }}
                className="absolute top-full left-1/2 -translate-x-1/2 mt-2 pt-1 pointer-events-none"
              >
                <div className="bg-[#050B14] border-[0.0625rem] border-white/20 rounded-full px-[1rem] py-[0.625rem] flex items-center gap-[1rem] shadow-[0_0.9375rem_2.5rem_rgba(0,0,0,0.9)] pointer-events-auto border-t-white/10 whitespace-nowrap">
                  <div className="flex items-center gap-[0.625rem] pr-[1rem] border-r border-white/10">
                    <Flame
                      size={18}
                      className="text-red-500 fill-red-500/20 drop-shadow-[0_0_0.625rem_rgba(239,68,68,0.7)]"
                    />
                    <span className="text-[0.6875rem] font-black text-white uppercase tracking-[0.15em] drop-shadow-[0_0.125rem_0.5rem_rgba(0,0,0,1)]">
                      {drip.level}
                    </span>
                  </div>

                  <div className="w-[9rem] h-[0.375rem] bg-white/20 rounded-full overflow-hidden border border-white/20 relative shadow-inner">
                    <motion.div
                      initial={{ width: 0 }}
                      animate={{
                        width: `${Math.max(3, Math.min(drip.progress * 100, 100))}%`,
                      }}
                      style={{ backgroundColor: "#FF0000" }}
                      className="h-full rounded-full shadow-[0_0_0.75rem_rgba(255,0,0,0.8)] relative"
                    >
                      {/* Shine Effect */}
                      <motion.div
                        animate={{ x: ["-100%", "200%"] }}
                        transition={{
                          duration: 2,
                          repeat: Infinity,
                          ease: "linear",
                        }}
                        className="absolute inset-0 w-full bg-gradient-to-r from-transparent via-white/40 to-transparent"
                      />
                    </motion.div>
                  </div>

                  <div className="flex items-center gap-[1rem] pl-[0.25rem]">
                    <div className="flex items-baseline gap-[0.25rem] leading-none">
                      <span className="text-[0.875rem] font-black text-white tabular-nums drop-shadow-md">
                        {drip.xp}
                      </span>
                      <span className="text-[0.5rem] font-bold text-red-500 uppercase tracking-tighter">
                        XP
                      </span>
                    </div>

                    <div className="bg-red-500/20 px-[0.5rem] py-[0.125rem] rounded-md border border-red-500/30">
                      <span className="text-[0.625rem] font-black text-red-400 tracking-widest leading-none">
                        LV.{drip.levelIndex}
                      </span>
                    </div>
                  </div>

                  {/* Item Breakdown Tooltip-style list — Deepened contrast */}
                  {drip.breakdown && drip.breakdown.length > 0 && (
                    <div className="flex items-center gap-[1.25rem] pl-[1.5rem] border-l border-white/15 ml-[0.5rem]">
                      {drip.breakdown.map((item, idx) => {
                        const slotMeta =
                          item.slotType === "Drawables"
                            ? DRAWABLE_SLOTS[item.slotIndex] ||
                              DRAWABLE_SLOTS_WEARABLE[item.slotIndex]
                            : PROP_SLOTS[item.slotIndex];

                        if (!slotMeta) return null;

                        return (
                          <div
                            key={`${item.slotType}-${item.slotIndex}-${idx}`}
                            className="flex items-center gap-[0.5rem] group/item transition-all"
                          >
                            <div className="p-[0.5rem] bg-white/5 rounded-lg border border-white/5 group-hover/item:bg-red-500/10 group-hover/item:border-red-500/30 transition-all">
                              <slotMeta.icon
                                size={14}
                                className="text-white/60 group-hover/item:text-red-400 transition-colors"
                              />
                            </div>
                            <span className="text-[0.75rem] font-black text-red-500 drop-shadow-[0_0_0.5rem_rgba(239,68,68,0.4)]">
                              +{item.rate}
                            </span>
                          </div>
                        );
                      })}
                    </div>
                  )}
                </div>
              </motion.div>
            )}
          </AnimatePresence>
        </motion.div>
      </div>
    </motion.div>
  );
}
