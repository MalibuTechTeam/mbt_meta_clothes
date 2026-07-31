import type { ThemeConfig } from "../types";

/** 6-char "rrggbb" hex (no leading #) → "r, g, b" triplet for rgba(). */
export function hexToRgb(hex: string): string {
  const r = parseInt(hex.slice(0, 2), 16);
  const g = parseInt(hex.slice(2, 4), 16);
  const b = parseInt(hex.slice(4, 6), 16);
  return `${r}, ${g}, ${b}`;
}

const HEX6 = /^[0-9a-fA-F]{6}$/;

/**
 * Build the CSS custom-property set from the server theme (config.lua
 * MBT.Theme). App applies these on :root, so laser, hotspot markers, scanner
 * rings and active states all share one accent — changing MBT.Theme.Accent
 * re-tints the whole NUI, glows included. index.css holds the defaults.
 *
 * Stessa convenzione di mbt_emote_menu, di proposito: chi ha già configurato
 * quello sa cosa aspettarsi qui.
 */
export function buildThemeVars(theme: ThemeConfig): Record<string, string> {
  // Un valore malformato non deve svuotare la UI: meglio tenere i default di
  // index.css che dipingere tutto di `NaN`.
  if (!theme || typeof theme.Accent !== "string" || !HEX6.test(theme.Accent)) {
    return {};
  }

  const accent = hexToRgb(theme.Accent);
  return {
    "--mbt-accent": `#${theme.Accent}`,
    "--mbt-accent-rgb": accent,
    "--mbt-accent-strong": `rgba(${accent}, 0.82)`,
    "--mbt-accent-glow": `rgba(${accent}, 0.25)`,
    "--mbt-accent-soft": `rgba(${accent}, 0.08)`,
  };
}

/** Applica il tema su :root. No-op se il Lua non ha inviato nulla di valido. */
export function applyTheme(theme?: ThemeConfig): void {
  const vars = buildThemeVars(theme as ThemeConfig);
  for (const [name, value] of Object.entries(vars)) {
    document.documentElement.style.setProperty(name, value);
  }
}
