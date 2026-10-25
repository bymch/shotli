import type { Background, Style, WallpaperId } from "./types";

export type Preset = {
  id: string;
  name: string;
  style: Style;
};

export const COLORS = [
  "#FFFFFF",
  "#F1F1F1",
  "#E7E5E4",
  "#E8EEF7",
  "#FDE2E4",
  "#E7F5EE",
  "#FFF6D8",
  "#1F2937",
  "#111827",
  "transparent",
];

export const GRADIENTS: { name: string; from: string; to: string; angle: number }[] = [
  { name: "Fog", from: "#F7F7F7", to: "#D9DEE7", angle: 180 },
  { name: "Dawn", from: "#FDE2E4", to: "#E0E7FF", angle: 140 },
  { name: "Sea", from: "#E0F2FE", to: "#D1FAE5", angle: 160 },
  { name: "Citrus", from: "#FEF3C7", to: "#FBCFE8", angle: 150 },
  { name: "Iris", from: "#3478F6", to: "#C4B5FD", angle: 135 },
  { name: "Ink", from: "#243044", to: "#111827", angle: 180 },
  { name: "Ember", from: "#FB923C", to: "#7C3AED", angle: 150 },
  { name: "Lagoon", from: "#22D3EE", to: "#6366F1", angle: 160 },
  { name: "Flamingo", from: "#FB7185", to: "#FBBF24", angle: 140 },
  { name: "Grove", from: "#34D399", to: "#0EA5E9", angle: 155 },
  { name: "Plum", from: "#F472B6", to: "#312E81", angle: 165 },
];

export const SCENES: { id: WallpaperId; name: string }[] = [
  { id: "dusk", name: "Dusk" },
  { id: "night", name: "Night" },
  { id: "harbour", name: "Harbour" },
  { id: "hills", name: "Hills" },
  { id: "aurora", name: "Aurora" },
  { id: "sorbet", name: "Sorbet" },
];

export const WALLPAPERS: { id: WallpaperId; name: string }[] = [
  { id: "dots", name: "Dots" },
  { id: "grid", name: "Grid" },
  { id: "diagonal", name: "Diagonal" },
  { id: "stripes", name: "Stripes" },
  { id: "mesh", name: "Mesh" },
  { id: "cross", name: "Graph" },
];

export const INK_COLORS = ["#E5484D", "#F5A524", "#3478F6", "#30A46C", "#8E4EC6", "#222222", "#FFFFFF"];

export const STROKE_WIDTHS = [2, 4, 6, 8];

export const FONT_SIZES = [18, 24, 32, 44];

function makeStyle(
  padding: number,
  radius: number,
  shadow: number,
  frame: Style["frame"],
  background: Background,
): Style {
  return { padding, radius, shadow, frame, background };
}

export const PRESETS: Preset[] = [
  {
    id: "clean",
    name: "Clean",
    style: makeStyle(56, 14, 28, "none", { kind: "color", color: "#FFFFFF" }),
  },
  {
    id: "studio",
    name: "Studio",
    style: makeStyle(80, 16, 42, "none", { kind: "gradient", from: "#F7F7F7", to: "#D9DEE7", angle: 180 }),
  },
  {
    id: "soft",
    name: "Soft",
    style: makeStyle(68, 22, 30, "none", { kind: "color", color: "#F4F1EC" }),
  },
  {
    id: "browser",
    name: "Browser",
    style: makeStyle(60, 12, 36, "browser", { kind: "color", color: "#E8EEF7" }),
  },
  {
    id: "window",
    name: "Window",
    style: makeStyle(52, 10, 24, "desktop", { kind: "wallpaper", id: "dots" }),
  },
  {
    id: "pastel",
    name: "Pastel",
    style: makeStyle(84, 24, 34, "none", { kind: "gradient", from: "#FDE2E4", to: "#E0E7FF", angle: 140 }),
  },
  {
    id: "signal",
    name: "Signal",
    style: makeStyle(76, 18, 48, "none", { kind: "gradient", from: "#3478F6", to: "#C4B5FD", angle: 135 }),
  },
  {
    id: "midnight",
    name: "Midnight",
    style: makeStyle(68, 14, 50, "browser", { kind: "color", color: "#16181D" }),
  },
];

export const DEFAULT_STYLE: Style = PRESETS[0].style;

export function stylesMatch(a: Style, b: Style) {
  return JSON.stringify(a) === JSON.stringify(b);
}

export function backgroundCss(background: Background) {
  if (background.kind === "color") {
    if (background.color === "transparent") {
      return "repeating-conic-gradient(#ececec 0% 25%, #ffffff 0% 50%) 0 0 / 12px 12px";
    }
    return background.color;
  }
  if (background.kind === "gradient") {
    return `linear-gradient(${background.angle}deg, ${background.from}, ${background.to})`;
  }
  switch (background.id) {
    case "dots":
      return "radial-gradient(#c9c5bf 1.1px, transparent 1.2px), #e8e6e3";
    case "grid":
      return "linear-gradient(#e4e4e4 1px, transparent 1px), linear-gradient(90deg, #e4e4e4 1px, transparent 1px), #f7f7f7";
    case "diagonal":
      return "repeating-linear-gradient(135deg, #eef2ff, #eef2ff 8px, #d9e2ff 8px, #d9e2ff 9px)";
    case "stripes":
      return "repeating-linear-gradient(#f4f1ec, #f4f1ec 8px, #ebe4d8 8px, #ebe4d8 16px)";
    case "mesh":
      return "radial-gradient(circle at 20% 20%, #fde2e4, transparent 45%), radial-gradient(circle at 80% 30%, #dbeafe, transparent 42%), radial-gradient(circle at 50% 80%, #d1fae5, transparent 40%), #f7f7f7";
    case "cross":
      return "linear-gradient(#dbe3f0 1px, transparent 1px), linear-gradient(90deg, #dbe3f0 1px, transparent 1px), #f4f7fb";
    case "dusk":
      return "linear-gradient(#ff8a5b, #f6b7c5 42%, #7c6bd4 72%, #1c1430)";
    case "night":
      return "linear-gradient(#070b18, #1a2744 55%, #070910)";
    case "harbour":
      return "linear-gradient(#f3c7a2, #8eadd4 40%, #245074 58%, #0e2438)";
    case "hills":
      return "linear-gradient(#ffd7c2, #f7a58a 40%, #8e5a78 70%, #3d2a3e)";
    case "aurora":
      return "linear-gradient(#07111f, #5eead4 40%, #a78bfa 62%, #071018)";
    case "sorbet":
      return "radial-gradient(circle at 16% 22%, #fb7185, transparent 42%), radial-gradient(circle at 80% 16%, #c4b5fd, transparent 40%), radial-gradient(circle at 58% 78%, #6ee7b7, transparent 42%), #fff6e8";
  }
}
