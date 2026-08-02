import React from "react";
import {
  Shirt,
  Glasses,
  Watch,
  ShieldCheck,
  Backpack,
  Drama,
  Ear,
  Footprints,
  Gem,
  Smile,
  HatGlasses,
  Sparkles,
} from "lucide-react";
import { SlotDefinition, CategorySlots } from "./types";

// Custom Trousers Icon (Lucide Lab)
const Trousers = ({
  size = 24,
  ...props
}: {
  size?: number;
  className?: string;
}) => (
  <svg
    xmlns="http://www.w3.org/2000/svg"
    width={size}
    height={size}
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    strokeWidth="2"
    strokeLinecap="round"
    strokeLinejoin="round"
    {...props}
  >
    <path d="M5 2c0 .6 1.4 1 3 1s3-.4 3-1h2c0 .6 1.4 1 3 1s3-.4 3-1v20c0 .6-1.4 1-3 1s-3-.4-3-1v-4l-3-2-3 2v4c0 .6-1.4 1-3 1s-3-.4-3-1V2Z" />
    <path d="M12 4v8" />
  </svg>
);

// The `label` fields here are identifiers for whoever reads the table, not text
// on screen: visible strings come from Lua (Locales[lang].UI) and are already
// translated. They stay in English like the rest of the code.

// Core slots (always visible)
export const DRAWABLE_SLOTS: Record<number, SlotDefinition> = {
  8: { label: "Top", icon: Shirt, category: "torso" },
  4: { label: "Pants", icon: Trousers, category: "legs" },
  6: { label: "Shoes", icon: Footprints, category: "feet" },
  7: { label: "Chain", icon: Gem, category: "accessories" },
};

// Extra slots (only visible when mbt_wearable_props is active)
export const DRAWABLE_SLOTS_WEARABLE: Record<number, SlotDefinition> = {
  1: { label: "Mask", icon: Drama, category: "head" },
  5: { label: "Backpack", icon: Backpack, category: "bags" },
  9: { label: "Body Armor", icon: ShieldCheck, category: "armor" },
};

export const PROP_SLOTS: Record<number, SlotDefinition> = {
  0: { label: "Hat", icon: HatGlasses, category: "head" },
  1: { label: "Glasses", icon: Glasses, category: "head" },
  2: { label: "Earrings", icon: Ear, category: "head" },
  6: { label: "Watch", icon: Watch, category: "accessories" },
  7: { label: "Bracelet", icon: Sparkles, category: "accessories" },
};

// Reserved for future wearable_props prop slots
export const PROP_SLOTS_WEARABLE: Record<number, SlotDefinition> = {};

// Map hotspot categories → which slots they show
export const CATEGORY_SLOTS: Record<string, CategorySlots> = {
  head: { Drawables: [], Props: [0, 1, 2] },
  torso: { Drawables: [8], Props: [] },
  accessories: { Drawables: [7], Props: [6, 7] },
  legs: { Drawables: [4], Props: [] },
  feet: { Drawables: [6], Props: [] },
};

export const CATEGORY_SLOTS_WEARABLE: Record<string, CategorySlots> = {
  head: { Drawables: [1], Props: [] },
  accessories: { Drawables: [], Props: [] },
  armor: { Drawables: [9], Props: [] },
  bags: { Drawables: [5], Props: [] },
};

export const HOTSPOT_META: Record<
  string,
  { icon: React.ComponentType<{ size?: number }>; label: string }
> = {
  head: { icon: Smile, label: "Head & Face" },
  torso: { icon: Shirt, label: "Torso" },
  accessories: { icon: Watch, label: "Accessories" },
  armor: { icon: ShieldCheck, label: "Body Armor" },
  bags: { icon: Backpack, label: "Bags" },
  legs: { icon: Trousers, label: "Pants" },
  feet: { icon: Footprints, label: "Shoes" },
};

// Clothing layer overlay metadata — one entry per slot that has a PNG layer.
// path: base filename without sex suffix and extension (e.g. "hat" → "hat_male.png" / "hat_female.png")
// availableFor is authoritative; check:assets verifies every declared PNG.
export interface LayerMeta {
  path: string;
  availableFor: readonly ("male" | "female")[];
  top: string;
  left: string;
  width: string;
  zIndex: number;
}

export const LAYER_META: Record<string, LayerMeta> = {
  // Props
  "Props-0": {
    path: "hat",
    availableFor: ["male"],
    top: "-1%",
    left: "50%",
    width: "19%",
    zIndex: 25,
  },
  "Props-1": {
    path: "glasses",
    availableFor: ["male"],
    top: "4.5%",
    left: "50%",
    width: "10%",
    zIndex: 24,
  },
  "Props-2": {
    path: "earrings",
    availableFor: ["male"],
    top: "6%",
    left: "50%",
    width: "13%",
    zIndex: 24,
  },
  "Props-6": {
    // below the jacket (zIndex 18) — the jacket covers the wrists
    path: "watch",
    availableFor: ["male"],
    top: "4%",
    left: "51.5%",
    width: "90%",
    zIndex: 17,
  },
  "Props-7": {
    // below the jacket (zIndex 18) — the jacket covers the wrists
    path: "bracelet",
    availableFor: ["male"],
    top: "39%",
    left: "40%",
    width: "17%",
    zIndex: 17,
  },
  // Drawables
  "Drawables-1": {
    path: "mask",
    availableFor: ["male"],
    top: "0%",
    left: "50%",
    width: "25%",
    zIndex: 27,
  },
  "Drawables-5": {
    path: "backpack",
    availableFor: [],
    top: "32%",
    left: "62%",
    width: "36%",
    zIndex: 10,
  },
  "Drawables-7": {
    path: "chain",
    availableFor: ["male"],
    top: "14%",
    left: "50%",
    width: "10%",
    zIndex: 22,
  },
  "Drawables-11": {
    path: "jacket",
    availableFor: ["male", "female"],
    top: "0%",
    left: "50%",
    width: "99%",
    zIndex: 18,
  },
  "Drawables-9": {
    path: "armor",
    availableFor: ["male"],
    top: "13.5%",
    left: "50%",
    width: "39%",
    zIndex: 19,
  },
  "Drawables-4": {
    path: "pants",
    availableFor: ["male"],
    top: "31%",
    left: "50%",
    width: "65%",
    zIndex: 15,
  },
  "Drawables-6": {
    path: "shoes",
    availableFor: ["male"],
    top: "1%",
    left: "50%",
    width: "100%",
    zIndex: 12,
  },
};
