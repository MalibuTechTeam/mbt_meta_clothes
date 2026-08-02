import type { ThemeConfig } from "../types";

const HEX6 = /^[0-9a-fA-F]{6}$/;

/** "rrggbb" (no '#') → "r, g, b", so rgba() can be composed with any alpha. */
function hexToRgb(hex: string): string {
  const channel = (offset: number) => parseInt(hex.slice(offset, offset + 2), 16);
  return `${channel(0)}, ${channel(2)}, ${channel(4)}`;
}

/**
 * Darkened variant of the accent, for solid fills: on a bright accent neither a
 * white nor a black glyph stays readable.
 */
function shade(hex: string, factor: number): string {
  const channel = (offset: number) =>
    Math.round(parseInt(hex.slice(offset, offset + 2), 16) * factor);
  return `rgb(${channel(0)}, ${channel(2)}, ${channel(4)})`;
}

/**
 * Expands config.lua MBT.Theme into the custom properties applied on :root, so a
 * single value re-tints the whole UI. Same convention as mbt_emote_menu.
 * Defaults live in index.css and stay put if the theme is missing or malformed.
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
