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
} from "lucide-react";
import { SlotDefinition, CategorySlots } from "./types";

// Custom Trousers Icon (Lucide Lab)
const Trousers = ({ size = 24, ...props }: { size?: number; className?: string }) => (
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

// Core slots (always visible)
export const DRAWABLE_SLOTS: Record<number, SlotDefinition> = {
  8: { label: "Top", icon: Shirt, category: "torso" },
  4: { label: "Pantaloni", icon: Trousers, category: "legs" },
  6: { label: "Scarpe", icon: Footprints, category: "feet" },
  7: { label: "Collana", icon: Gem, category: "accessories" },
};

// Extra slots (only visible when mbt_wearable_props is active)
export const DRAWABLE_SLOTS_WEARABLE: Record<number, SlotDefinition> = {
  1: { label: "Maschera", icon: Drama, category: "head" },
  5: { label: "Zaino", icon: Backpack, category: "bags" },
  9: { label: "Giubbotto", icon: ShieldCheck, category: "armor" },
};

export const PROP_SLOTS: Record<number, SlotDefinition> = {
  0: { label: "Cappello", icon: HatGlasses, category: "head" },
  1: { label: "Occhiali", icon: Glasses, category: "head" },
  2: { label: "Orecchini", icon: Ear, category: "head" },
  6: { label: "Orologio", icon: Watch, category: "accessories" },
};

// Reserved for future wearable_props prop slots
export const PROP_SLOTS_WEARABLE: Record<number, SlotDefinition> = {};

// Map hotspot categories → which slots they show
export const CATEGORY_SLOTS: Record<string, CategorySlots> = {
  head: { Drawables: [], Props: [0, 1, 2] },
  torso: { Drawables: [8], Props: [] },
  accessories: { Drawables: [7], Props: [6] },
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
  head: { icon: Smile, label: "Testa & Volto" },
  torso: { icon: Shirt, label: "Torso" },
  accessories: { icon: Watch, label: "Accessori" },
  armor: { icon: ShieldCheck, label: "Kevlar" },
  bags: { icon: Backpack, label: "Zaini" },
  legs: { icon: Trousers, label: "Pantaloni" },
  feet: { icon: Footprints, label: "Scarpe" },
};
