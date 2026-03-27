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
}

export interface NUIMessageHairToggleUpdate {
  action: 'hairToggleUpdate';
  hairToggled: boolean;
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
}

export interface DripState {
  xp: number;
  rate: number;
  level: string;
  levelIndex: number;
  progress: number;
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
  | NUIMessageUpdateWearing;
