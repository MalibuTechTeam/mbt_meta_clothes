import type { ThemeConfig } from "../types";

const HEX6 = /^[0-9a-fA-F]{6}$/;

/** "rrggbb" (senza '#') → "r, g, b", per comporre rgba() con qualunque alpha. */
function hexToRgb(hex: string): string {
  const channel = (offset: number) => parseInt(hex.slice(offset, offset + 2), 16);
  return `${channel(0)}, ${channel(2)}, ${channel(4)}`;
}

/**
 * Versione scurita dell'accento, per i riempimenti pieni: su un accento
 * brillante non si legge né un glifo bianco né uno nero.
 */
function shade(hex: string, factor: number): string {
  const channel = (offset: number) =>
    Math.round(parseInt(hex.slice(offset, offset + 2), 16) * factor);
  return `rgb(${channel(0)}, ${channel(2)}, ${channel(4)})`;
}

/**
 * Espande config.lua MBT.Theme nelle custom property applicate su :root, così
 * un solo valore ritinge tutta la UI. Stessa convenzione di mbt_emote_menu.
 * I default vivono in index.css e restano se il tema è assente o malformato.
 */
export function buildThemeVars(theme?: ThemeConfig): Record<string, string> {
  if (!theme || typeof theme.Accent !== "string" || !HEX6.test(theme.Accent)) {
    return {};
  }

  const accent = hexToRgb(theme.Accent);
  return {
    "--mbt-accent": `#${theme.Accent}`,
    "--mbt-accent-rgb": accent,
    "--mbt-accent-strong": `rgba(${accent}, 0.82)`,
    "--mbt-accent-dark": shade(theme.Accent, 0.62),
    "--mbt-accent-deep": shade(theme.Accent, 0.42),
    "--mbt-accent-glow": `rgba(${accent}, 0.25)`,
    "--mbt-accent-soft": `rgba(${accent}, 0.08)`,
  };
}

export function applyTheme(theme?: ThemeConfig): void {
  for (const [name, value] of Object.entries(buildThemeVars(theme))) {
    document.documentElement.style.setProperty(name, value);
  }
}
