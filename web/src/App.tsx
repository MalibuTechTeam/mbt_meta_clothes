import { useState, useEffect, useCallback, useMemo } from "react";
import { motion, AnimatePresence } from "framer-motion";
import Mannequin from "./components/Mannequin";
import { fetchNui } from "./utils/fetchNui";
import {
  Shirt,
  Glasses,
  Watch,
  ShieldCheck,
  Backpack,
  Crown,
  Drama,
  Ear,
  Footprints,
  Gem,
  RefreshCw,
  Pocket,
  Smile,
} from "lucide-react";
import "./index.css";

import type {
  WearingState,
  ExtraState,
  SlotDefinition,
  ActiveCategory,
  CategorySlots,
  NUIMessage,
  NUIMessageUI,
  DripState,
  ToggleableSlots,
  StealItem,
  NUIMessageStealMenu,
  NUIMessageUpdateSlot,
  NUIMessageUpdateWearing,
} from "./types";

import {
  DRAWABLE_SLOTS,
  DRAWABLE_SLOTS_WEARABLE,
  PROP_SLOTS,
  PROP_SLOTS_WEARABLE,
  CATEGORY_SLOTS,
  CATEGORY_SLOTS_WEARABLE,
  HOTSPOT_META,
  LAYER_META,
} from "./constants";

export default function App() {
  const [visible, setVisible] = useState(false);
  // Contatore incrementato ad ogni apertura della UI — usato come parte della
  // key del wrapper motion così se l'utente chiude e riapre velocemente,
  // AnimatePresence non può invertire l'exit in corso (che impedirebbe il
  // replay dell'animazione initial). Nuova key = unmount + remount forzati.
  const [openCount, setOpenCount] = useState(0);
  const [activeCategory, setActiveCategory] = useState<ActiveCategory>({
    id: null,
    rect: null,
  });
  const [wearing, setWearing] = useState<WearingState>({
    Drawables: {},
    Props: {},
  });
  const [extraState, setExtraState] = useState<ExtraState>({
    mask: false,
    bag: false,
    armor: false,
    wearableProps: false,
  });
  const [sex, setSex] = useState<0 | 1>(0);
  const [drip, setDrip] = useState<DripState>({
    xp: 0,
    rate: 0,
    level: "Freshman",
    levelIndex: 1,
    progress: 0,
  });
  const [toggleableSlots, setToggleableSlots] = useState<ToggleableSlots>({
    Drawables: {},
    Props: {},
  });
  const [hairToggled, setHairToggled] = useState(false);
  const [hairToggleable, setHairToggleable] = useState(false);
  const [stealMode, setStealMode] = useState(false);
  const [stealItems, setStealItems] = useState<StealItem[]>([]);
  // Snapshot di cosa la vittima indossa, ricevuto dal server quando apre il
  // menu steal. Usato per far vedere sul mannequin i suoi vestiti (non i nostri)
  // durante lo steal mode.
  const [stealWearing, setStealWearing] = useState<WearingState>({
    Drawables: {},
    Props: {},
  });
  const [stealSex, setStealSex] = useState<0 | 1>(0);

  const handleExitUI = useCallback(() => {
    setVisible(false);
    setStealMode(false);
    setStealItems([]);
    setActiveCategory({ id: null, rect: null });
    fetchNui("exitUI").catch(() => {});
  }, []);

  // Preload tutte le PNG pesanti subito al mount dell'app (ancor prima che
  // la UI sia aperta dal server). Evita il micro-lag alla prima apertura:
  // il browser decodifica/cachea mannequin + layer in background mentre
  // l'utente gioca, così al primo `visible=true` le immagini sono pronte.
  useEffect(() => {
    const paths = new Set<string>([
      "./mannequin_male.png",
      "./mannequin_female.png",
    ]);
    Object.values(LAYER_META).forEach((meta) => {
      paths.add(`./layers/${meta.path}_male.png`);
      paths.add(`./layers/${meta.path}_female.png`);
    });
    paths.forEach((src) => {
      const img = new Image();
      img.src = src; // avvia download + decode in background
    });
  }, []);

  useEffect(() => {
    const handleMessage = (event: MessageEvent<NUIMessage>) => {
      const { action } = event.data;

      if (action === "ui") {
        const d = event.data as NUIMessageUI;
        const isVisible =
          d.status === true || d.status === "true" || d.status === 1;
        setVisible(isVisible);
        if (isVisible) {
          setOpenCount((c) => c + 1); // forza remount per replayare initial anim
          setStealMode(false); // Normal UI reset
          setActiveCategory({ id: null, rect: null }); // FIX: Clear stale category on open
          if (d.wearing) setWearing(d.wearing);
          if (d.sex !== undefined) setSex(d.sex);
          setExtraState({
            mask: d.mask || false,
            bag: d.bag || false,
            armor: d.armor || false,
            wearableProps: d.wearableProps || false,
          });
          if (d.toggleableSlots) setToggleableSlots(d.toggleableSlots);
          if (d.hairToggled !== undefined) setHairToggled(d.hairToggled);
          if (d.hairToggleable !== undefined)
            setHairToggleable(d.hairToggleable);
          if (d.drip) setDrip(d.drip);
        }
        if (!isVisible) {
          setActiveCategory({ id: null, rect: null });
        }
      }

      if (action === "stealMenu") {
        const d = event.data as NUIMessageStealMenu;
        const isVisible = d.status === true;
        setVisible(isVisible);
        if (isVisible) {
          setOpenCount((c) => c + 1); // forza remount per replayare initial anim
          setStealMode(true);
          setActiveCategory({ id: null, rect: null }); // FIX: Clear stale category on open
          if (d.items) setStealItems(d.items);
          // Snapshot del victim wearing: cosa indossa l'obiettivo del furto.
          // Passato al mannequin in steal mode così vedi i SUOI vestiti, non i tuoi.
          setStealWearing(d.wearing || { Drawables: {}, Props: {} });
          if (d.sex !== undefined) setStealSex(d.sex);
        } else {
          setStealItems([]);
          setStealWearing({ Drawables: {}, Props: {} });
          setActiveCategory({ id: null, rect: null });
        }
      }

      if (action === "dripUpdate") {
        const d = event.data as {
          action: string;
          xp: number;
          rate: number;
          level: string;
          levelIndex: number;
          progress: number;
          breakdown?: any;
        };
        setDrip((prev) => ({
          ...prev,
          xp: d.xp !== undefined ? d.xp : prev.xp,
          rate: d.rate !== undefined ? d.rate : prev.rate,
          level: d.level !== undefined ? d.level : prev.level,
          levelIndex:
            d.levelIndex !== undefined ? d.levelIndex : prev.levelIndex,
          progress: d.progress !== undefined ? d.progress : prev.progress,
          breakdown: d.breakdown !== undefined ? d.breakdown : prev.breakdown,
        }));
      }

      if (action === "hairToggleUpdate") {
        const d = event.data as { action: string; hairToggled: boolean };
        setHairToggled(d.hairToggled);
      }

      if (action === "extraStateUpdate") {
        const d = event.data as Partial<ExtraState>;
        setExtraState((prev) => ({ ...prev, ...d }));
      }

      if (action === "updateWearing") {
        const d = event.data as { action: string; wearing: WearingState };
        if (d.wearing) setWearing(d.wearing);
      }

      if (action === "updateSlot") {
        const d = event.data as NUIMessageUpdateSlot;
        const { slotType, slotIndex, isWearing, drawable, texture } = d;
        setWearing((prev) => {
          // Normalize slotType casing ('drawable' -> 'Drawables', 'prop' -> 'Props')
          const rawType = slotType.toLowerCase();
          const type = (
            rawType.includes("drawable") ? "Drawables" : "Props"
          ) as keyof WearingState;

          const next = { ...prev, [type]: { ...prev[type] } };
          const key = String(slotIndex);
          if (isWearing) {
            next[type][key] = {
              index: slotIndex,
              drawable: drawable ?? 0,
              texture: texture ?? 0,
            };
          } else {
            delete next[type][key];
          }
          return next;
        });
      }
    };

    window.addEventListener("message", handleMessage as EventListener);

    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === "Escape" || e.key === "Backspace") {
        handleExitUI();
      }
    };
    window.addEventListener("keydown", handleKeyDown);

    // Dev mode: auto-open with mock wearing data
    if (!window.invokeNative) {
      setTimeout(() => {
        setVisible(true);
        setWearing({
          Drawables: {
            "4": { index: 4, drawable: 43, texture: 0 },
            "6": { index: 6, drawable: 7, texture: 0 },
            "11": { index: 11, drawable: 93, texture: 0 },
          },
          Props: {
            "0": { index: 0, drawable: 5, texture: 0 },
          },
        });
        setDrip({
          xp: 342,
          rate: 5,
          level: "Stylish",
          levelIndex: 3,
          progress: 0.57,
        });
        setToggleableSlots({
          Drawables: { "11": true, "2": true },
          Props: { "0": true },
        });
      }, 500);
    }

    return () => {
      window.removeEventListener("message", handleMessage as EventListener);
      window.removeEventListener("keydown", handleKeyDown);
    };
  }, []);

  const handleSlotClick = useCallback(
    (slotType: "Drawables" | "Props", slotIndex: number) => {
      // Slot 8 (Top) special check
      if (slotType === "Drawables" && slotIndex === 8) {
        if (!wearing.Drawables?.["8"] && !wearing.Drawables?.["11"]) return;
      // wearable_props slots: check extraState booleans instead of wearing table
      } else if (slotType === "Drawables" && slotIndex === 1) {
        if (!extraState.mask) return;
      } else if (slotType === "Drawables" && slotIndex === 5) {
        if (!extraState.bag) return;
      } else if (slotType === "Drawables" && slotIndex === 9) {
        if (!extraState.armor) return;
      } else {
        if (!wearing[slotType]?.[String(slotIndex)]) return;
      }

      if (slotType === "Drawables") {
        fetchNui("handleDress", { Index: slotIndex });
      } else {
        fetchNui("handleProps", { Index: slotIndex });
      }
    },
    [wearing],
  );

  const handleToggleClick = useCallback(
    (slotType: "Drawables" | "Props", slotIndex: number) => {
      // Torso kit: button is slot 8 but ClothingStates are on slot 11 (jacket)
      const effectiveIndex =
        slotType === "Drawables" && slotIndex === 8 ? 11 : slotIndex;
      fetchNui("handleToggleState", { slotType, slotIndex: effectiveIndex });
    },
    [],
  );

  const isSlotToggleable = useCallback(
    (slotType: "Drawables" | "Props", slotIndex: number): boolean => {
      // Torso kit: slot 8 button represents jacket (slot 11) — check slot 11 states
      if (slotType === "Drawables" && slotIndex === 8) {
        return !!(
          toggleableSlots["Drawables"]?.["11"] ||
          toggleableSlots["Drawables"]?.["8"]
        );
      }
      return !!toggleableSlots[slotType]?.[String(slotIndex)];
    },
    [toggleableSlots],
  );

  const isSlotWorn = useCallback(
    (slotType: "Drawables" | "Props", slotIndex: number): boolean => {
      // Torso kit: slot 8 is "worn" if 8 or 11 has an item (exclude index 3 which is arms/skin)
      if (slotType === "Drawables" && slotIndex === 8) {
        return !!(wearing.Drawables?.["8"] || wearing.Drawables?.["11"]);
      }
      // wearable_props slots: worn state comes from extraState booleans, not wearing table
      if (slotType === "Drawables" && slotIndex === 1) return !!extraState.mask;
      if (slotType === "Drawables" && slotIndex === 5) return !!extraState.bag;
      if (slotType === "Drawables" && slotIndex === 9) return !!extraState.armor;
      return !!wearing[slotType]?.[String(slotIndex)];
    },
    [wearing, extraState],
  );

  // Laser HUD math
  const hasActive = activeCategory.id !== null && activeCategory.rect !== null;
  const startX = hasActive ? activeCategory.rect!.left : 0;
  const startY = hasActive ? activeCategory.rect!.top : 0;

  // Il pannello si aprirà esattamente a 40px di distanza dal punto cliccato sul manichino
  const laserLength = 100;

  // Scaling factor for absolute pixel calculations
  const scale = window.innerHeight / 1080;

  const activeCategorySlots = useMemo(() => {
    if (!hasActive || !activeCategory.id) return null;
    const base = CATEGORY_SLOTS[activeCategory.id];
    const extra = extraState.wearableProps
      ? CATEGORY_SLOTS_WEARABLE[activeCategory.id]
      : null;
    if (!base && !extra) return null;
    return {
      Drawables: [...(base?.Drawables || []), ...(extra?.Drawables || [])],
      Props: [...(base?.Props || []), ...(extra?.Props || [])],
    };
  }, [hasActive, activeCategory.id, extraState.wearableProps]);
  const activeMeta =
    hasActive && activeCategory.id ? HOTSPOT_META[activeCategory.id] : null;

  // Stagger variants for items
  const containerVariants = {
    hidden: { opacity: 0 },
    show: {
      opacity: 1,
      transition: {
        staggerChildren: 0.05,
        delayChildren: 0.1,
      },
    },
  };

  const itemVariants = {
    hidden: { opacity: 0, scale: 0.8, y: 10 },
    show: {
      opacity: 1,
      scale: 1,
      y: 0,
      transition: { type: "spring" as const, stiffness: 300, damping: 20 },
    },
  };

  // Render a single slot button
  const renderSlot = (
    slotType: "Drawables" | "Props",
    slotIndex: number,
    slotDef: SlotDefinition,
  ) => {
    const worn = isSlotWorn(slotType, slotIndex);
    const toggleable = isSlotToggleable(slotType, slotIndex);
    const SlotIcon = slotDef.icon;

    return (
      <motion.div
        key={`${slotType}-${slotIndex}`}
        variants={itemVariants}
        className="relative mx-auto"
      >
        <motion.button
          whileHover={worn ? { scale: 1.05 } : {}}
          whileTap={worn ? { scale: 0.95 } : {}}
          onClick={(e) => {
            e.stopPropagation();
            handleSlotClick(slotType, slotIndex);
          }}
          className={`aspect-square w-[3.5rem] rounded-full flex items-center justify-center relative group transition-all duration-300 pointer-events-auto
            ${
              worn
                ? "bg-white/10 border-[0.0625rem] border-white/40 cursor-pointer shadow-[0_0_1.25rem_rgba(255,255,255,0.05)]"
                : "bg-[#0B121D]/40 border-[0.0625rem] border-white/5 opacity-50 cursor-default hover:bg-[#0B121D]/60"
            }`}
        >
          {/* Active Orbit Ring */}
          {worn && (
            <motion.div
              layoutId="orbit-ring"
              className="absolute -inset-1.5 border border-blue-500/40 rounded-full"
              initial={{ opacity: 0, scale: 0.8 }}
              animate={{ opacity: 1, scale: 1 }}
              transition={{ duration: 0.3 }}
            />
          )}

          <SlotIcon
            size={20}
            strokeWidth={1.5}
            className={`transition-all duration-300 ${
              worn
                ? "text-white drop-shadow-[0_0_8px_rgba(255,255,255,0.5)]"
                : "text-white/40"
            }`}
          />
        </motion.button>

        {/* Toggle/Swap button — only visible when slot is worn AND has ClothingStates */}
        {worn && toggleable && (
          <motion.button
            initial={{ opacity: 0, scale: 0 }}
            animate={{ opacity: 1, scale: 1 }}
            whileHover={{ scale: 1.15 }}
            whileTap={{ scale: 0.9 }}
            onClick={(e) => {
              e.stopPropagation();
              handleToggleClick(slotType, slotIndex);
            }}
            className="absolute -bottom-1 -right-1 w-6 h-6 rounded-full bg-cyan-500/80 border border-cyan-300/50 flex items-center justify-center cursor-pointer shadow-[0_0_10px_rgba(34,211,238,0.4)] hover:bg-cyan-400/90 transition-colors z-10"
            title="Toggle style"
          >
            <RefreshCw size={11} strokeWidth={2.5} className="text-white" />
          </motion.button>
        )}
      </motion.div>
    );
  };

  return (
    <div className="w-screen h-screen bg-transparent select-none relative overflow-hidden font-sans">
      <AnimatePresence>
        {visible && (
          <motion.div
            key={`main-app-ui-${openCount}`}
            variants={{
              hidden: { opacity: 0 },
              show: { opacity: 1 },
            }}
            initial="hidden"
            animate="show"
            exit="hidden"
            transition={{ duration: 0.3 }}
            className="absolute inset-0 w-full h-full flex items-center justify-center overflow-hidden"
          >
            {/* Safe Center Area: Constrains UI to a virtual 16:9 box on Ultrawide */}
            <div className="relative w-full h-full max-w-[177.77vh] mx-auto pointer-events-none">
              {/* Background Backdrop - Moved inside for sync */}
              <motion.div
                variants={{
                  hidden: { opacity: 0 },
                  show: { opacity: 1 },
                }}
                transition={{ duration: 0.3 }}
                className="absolute inset-0 z-0 bg-transparent pointer-events-auto"
                style={{
                  background:
                    "linear-gradient(to right, transparent 0%, transparent 30%, rgba(5, 11, 20, 0.8) 65%, rgba(0, 4, 10, 0.95) 100%)",
                }}
                onClick={() => setActiveCategory({ id: null, rect: null })}
              />

              <Mannequin
                activeCategory={activeCategory.id}
                // In stealMode mostriamo il VICTIM (wearing+sex ricevuti dal
                // server all'apertura dello steal menu), altrimenti il ladro.
                wearing={stealMode ? stealWearing : wearing}
                sex={stealMode ? stealSex : sex}
                drip={drip}
                wearableProps={extraState.wearableProps}
                hairToggled={hairToggled}
                hairToggleable={hairToggleable}
                stealMode={stealMode}
                stealItems={stealItems}
                // In stealMode NON passiamo isSlotWorn (che legge extraState
                // del ladro). Il render userà il fallback sul wearing prop
                // diretto — che è già il victim wearing.
                isSlotWorn={stealMode ? undefined : isSlotWorn}
                onClose={handleExitUI}
                onCategoryClick={(id, rect) => {
                  if (activeCategory.id === id) {
                    setActiveCategory({ id: null, rect: null });
                  } else {
                    setActiveCategory({ id, rect });
                  }
                }}
              />

              {/* SVG Laser HUD */}
              <svg className="absolute inset-0 w-full h-full pointer-events-none z-10 drop-shadow-[0_0_5px_rgba(255,255,255,0.5)]">
                <AnimatePresence>
                  {hasActive && (
                    <motion.g
                      key={`laser-${activeCategory.id}`}
                      initial={{ opacity: 0 }}
                      animate={{ opacity: 1 }}
                      exit={{ opacity: 0 }}
                      transition={{ duration: 0.3 }}
                    >
                      <motion.circle
                        cx={startX}
                        cy={startY}
                        r={2}
                        fill="white"
                      />
                      <motion.path
                        initial={{ pathLength: 0 }}
                        animate={{ pathLength: 1 }}
                        exit={{ pathLength: 0 }}
                        transition={{ duration: 0.4, ease: "easeOut" }}
                        d={`M ${startX} ${startY} 
                         L ${startX - 20 * scale} ${startY} 
                         L ${startX - 40 * scale} ${startY + 20 * scale} 
                         L ${startX - 100 * scale} ${startY + 20 * scale} 
                         L ${startX - 120 * scale} ${startY} 
                         L ${startX - (laserLength + 260) * scale} ${startY}`}
                        stroke="rgba(255,255,255,0.25)"
                        strokeWidth="1"
                        fill="none"
                      />
                      {/* Energy Flow Path */}
                      <motion.path
                        initial={{
                          pathLength: 0,
                          opacity: 0,
                          strokeDashoffset: 100,
                        }}
                        animate={{
                          pathLength: 1,
                          opacity: 1,
                          strokeDashoffset: 0,
                        }}
                        exit={{ opacity: 0 }}
                        transition={{
                          pathLength: { duration: 0.4, ease: "easeOut" },
                          opacity: { duration: 0.4 },
                          strokeDashoffset: {
                            duration: 2,
                            repeat: Infinity,
                            ease: "linear",
                          },
                        }}
                        d={`M ${startX} ${startY} 
                         L ${startX - 20 * scale} ${startY} 
                         L ${startX - 40 * scale} ${startY + 20 * scale} 
                         L ${startX - 100 * scale} ${startY + 20 * scale} 
                         L ${startX - 120 * scale} ${startY} 
                         L ${startX - (laserLength + 260) * scale} ${startY}`}
                        stroke="url(#laserGradient)"
                        strokeWidth="1.5"
                        strokeDasharray="10 20"
                        fill="none"
                      />
                      <defs>
                        <linearGradient
                          id="laserGradient"
                          x1="0%"
                          y1="0%"
                          x2="100%"
                          y2="0%"
                        >
                          <stop offset="0%" stopColor="rgba(37, 99, 235, 0)" />
                          <stop
                            offset="50%"
                            stopColor="rgba(37, 99, 235, 0.8)"
                          />
                          <stop
                            offset="100%"
                            stopColor="rgba(37, 99, 235, 0)"
                          />
                        </linearGradient>
                      </defs>
                    </motion.g>
                  )}
                </AnimatePresence>
              </svg>

              {/* Floating Contextual Panel */}
              <AnimatePresence mode="wait">
                {hasActive && activeMeta && (
                  <motion.div
                    key={`panel-${activeCategory.id}`}
                    initial={{ opacity: 0, x: 20, scale: 0.95 }}
                    animate={{ opacity: 1, x: 0, scale: 1 }}
                    exit={{ opacity: 0, x: 20, scale: 0.95 }}
                    transition={{
                      type: "spring" as const,
                      stiffness: 350,
                      damping: 25,
                    }}
                    className="absolute z-20 flex flex-col pointer-events-auto"
                    style={{
                      right: `calc(100% - ${startX}px + 6.25rem)`,
                      top: `${startY}px`,
                      width: "16.25rem",
                    }}
                  >
                    <div className="absolute bottom-full left-0 w-full flex justify-between items-end pb-2">
                      <h2 className="text-white text-[1rem] font-bold tracking-wider flex items-center gap-2 px-1 drop-shadow-[0_2px_8px_rgba(0,0,0,1)]">
                        {activeMeta.label}
                      </h2>
                    </div>

                    <div className="flex-1 overflow-y-auto custom-scrollbar pr-[0.25rem] pt-[1.5rem]">
                      <motion.div
                        variants={containerVariants}
                        initial="hidden"
                        animate="show"
                        className="grid grid-cols-3 gap-y-[1.5rem] gap-x-[0.5rem] py-[0.5rem] overflow-visible"
                      >
                        {activeCategorySlots?.Drawables.map((idx) => {
                          const def =
                            DRAWABLE_SLOTS[idx] || DRAWABLE_SLOTS_WEARABLE[idx];
                          return def ? renderSlot("Drawables", idx, def) : null;
                        })}
                        {activeCategorySlots?.Props.map((idx) => {
                          const def =
                            PROP_SLOTS[idx] || PROP_SLOTS_WEARABLE[idx];
                          return def ? renderSlot("Props", idx, def) : null;
                        })}

                        {activeCategorySlots &&
                          activeCategorySlots.Drawables.length === 0 &&
                          activeCategorySlots.Props.length === 0 && (
                            <div className="col-span-4 py-8 text-center">
                              <p className="text-white/30 text-[0.875rem]">
                                {extraState.wearableProps
                                  ? "Nessun oggetto in questa categoria"
                                  : "Disponibile con mbt_wearable_props"}
                              </p>
                            </div>
                          )}
                      </motion.div>
                    </div>
                  </motion.div>
                )}
              </AnimatePresence>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
