// Slot data received from Lua
export interface SlotData {
  index: number;
  drawable: number;
  texture: number;
}

// Full wearing state from Lua SendNUIMessage
export interface WearingState {
  Drawables: Record<string, SlotData>;
  Props: Record<string, SlotData>;
}

// Extra state flags from Lua
export interface ExtraState {
  mask: boolean;
  bag: boolean;
  armor: boolean;
  wearableProps: boolean;
}

// Slot definition for UI rendering
export interface SlotDefinition {
  label: string;
  icon: React.ComponentType<{ size?: number; strokeWidth?: number; className?: string }>;
  category: string;
}

// Active category state
export interface ActiveCategory {
  id: string | null;
  rect: { left: number; top: number } | null;
}

// Category slot mapping
export interface CategorySlots {
  Drawables: number[];
  Props: number[];
}

// Toggleable slots state (which slots have ClothingStates configured)
export interface ToggleableSlots {
  Drawables: Record<string, boolean>;
  Props: Record<string, boolean>;
}

// NUI message types from Lua
export interface NUIMessageUI {
  action: 'ui';
  status: boolean | string | number;
  sex?: 0 | 1;
  wearing?: WearingState;
  mask?: boolean;
  bag?: boolean;
  armor?: boolean;
  wearableProps?: boolean;
  toggleableSlots?: ToggleableSlots;
  hairToggled?: boolean;
  hairToggleable?: boolean;
  drip?: DripState;
  labels?: UILabels;
}

export interface NUIMessageHairToggleUpdate {
  action: 'hairToggleUpdate';
  hairToggled: boolean;
}

export interface NUIMessageExtraStateUpdate {
  action: 'extraStateUpdate';
  mask?: boolean;
  bag?: boolean;
  armor?: boolean;
  wearableProps?: boolean;
}

export interface NUIMessageUpdateSlot {
  action: 'updateSlot';
  slotType: 'Drawables' | 'Props';
  slotIndex: number;
  isWearing: boolean;
  drawable?: number;
  texture?: number;
}

export interface NUIMessageDripUpdate {
  action: 'dripUpdate';
  xp: number;
  rate: number;
  level: string;
  levelIndex: number;
  progress: number;
  breakdown?: { slotType: 'Drawables' | 'Props'; slotIndex: number; rate: number }[];
}

export interface DripState {
  xp: number;
  rate: number;
  level: string;
  levelIndex: number;
  progress: number;
  breakdown?: { slotType: 'Drawables' | 'Props'; slotIndex: number; rate: number }[];
}

export interface StealItem {
  label: string;
  stealType: string;
  slotIndex: number | null;
}

export interface NUIMessageStealMenu {
  action: 'stealMenu';
  status: boolean;
  items?: StealItem[];
  wearing?: WearingState;
  sex?: 0 | 1;
  labels?: UILabels;
}

/**
 * Dizionario stringhe UI inviato dal Lua (dal locale attivo) ad ogni
 * apertura della NUI. Unica fonte di verità per le traduzioni frontend.
 * Lato Lua vive in Locales[lang].UI (vedi locales/en.lua, locales/it.lua).
 */
export interface UILabels {
  hotspots: {
    head: string;
    torso: string;
    accessories: string;
    armor: string;
    bags: string;
    legs: string;
    feet: string;
  };
  slots: {
    hat: string;
    glasses: string;
    earrings: string;
    watch: string;
    bracelet: string;
    mask: string;
    backpack: string;
    armor: string;
    chain: string;
    top: string;
    pants: string;
    shoes: string;
  };
  steal: {
    stealAll: string;
    collect: string;
    lootingInProgress: string;
  };
}

export interface NUIMessageUpdateWearing {
  action: 'updateWearing';
  wearing: WearingState;
}

export type NUIMessage =
  | NUIMessageUI
  | NUIMessageUpdateSlot
  | NUIMessageDripUpdate
  | NUIMessageStealMenu
  | NUIMessageHairToggleUpdate
  | NUIMessageExtraStateUpdate
  | NUIMessageUpdateWearing;
