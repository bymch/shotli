import type { Background, CanvasRatio, CardStyle, Style, WallpaperId } from "./types";

export type Preset = {
  id: string;
  name: string;
  style: Style;
};

// Solid colours and three-stop gradients from Screendrop, which is CC0.
export const COLORS = [
  "#050506",
  "#F5F5F0",
  "#2B2E36",
  "#F03B47",
  "#F78529",
  "#F5BA3B",
  "#3B9C5C",
  "#2980E0",
  "#7A42E8",
  "#EDA89E",
  "#A8E6BA",
  "#A1C9F0",
  "#CCC2EB",
  "#FACCB0",
  "#BDD1B2",
  "#E8DEC2",
  "transparent",
];

export const GRADIENTS: { name: string; from: string; mid: string; to: string; angle: number }[] = [
  { name: "Aurora", from: "#FA4F94", mid: "#6652F2", to: "#4AD6CC", angle: 135 },
  { name: "Cobalt", from: "#0A0D80", mid: "#4230ED", to: "#6BABFA", angle: 153 },
  { name: "Peach", from: "#FA615C", mid: "#FCB55C", to: "#E654A6", angle: 135 },
  { name: "Glass", from: "#DEF2F0", mid: "#75C4DB", to: "#4087ED", angle: 135 },
  { name: "Plasma", from: "#140538", mid: "#591FD6", to: "#F2426B", angle: 225 },
  { name: "Mango", from: "#FCBF33", mid: "#F55436", to: "#AB30E3", angle: 135 },
  { name: "Mist", from: "#F0F0EB", mid: "#CCE0F0", to: "#F2C2B2", angle: 135 },
  { name: "Lagoon", from: "#144C8A", mid: "#40A3B8", to: "#B2EBC7", angle: 315 },
  { name: "Ember", from: "#2E0814", mid: "#DB2B2E", to: "#FFAB40", angle: 135 },
  { name: "Violet", from: "#3D1482", mid: "#9638F0", to: "#F56BBD", angle: 153 },
  { name: "Sea Glass", from: "#6EDBBF", mid: "#409ECC", to: "#3859BF", angle: 135 },
  { name: "Citrus", from: "#FCE84C", mid: "#70C74A", to: "#1F946B", angle: 225 },
  { name: "Amethyst", from: "#1A1447", mid: "#5926A6", to: "#C263F2", angle: 315 },
  { name: "Sorbet", from: "#FF7D82", mid: "#FFBD7A", to: "#8FC7FA", angle: 135 },
  { name: "Mineral", from: "#EDF5F2", mid: "#A3B8D1", to: "#546B8C", angle: 135 },
  { name: "Dawn", from: "#FA9EC4", mid: "#FAD178", to: "#6BB5F5", angle: 315 },
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

export const CANVASES: { id: CanvasRatio; label: string }[] = [
  { id: "auto", label: "Auto" },
  { id: "1:1", label: "1:1" },
  { id: "4:3", label: "4:3" },
  { id: "3:2", label: "3:2" },
  { id: "16:9", label: "16:9" },
];

function makeStyle(
  padding: number,
  radius: number,
  shadow: number,
  frame: Style["frame"],
  background: Background,
  canvas: CanvasRatio = "auto",
  card: CardStyle = "default",
  tilt = 0,
  borderWidth = 0,
): Style {
  return {
    padding,
    radius,
    shadow,
    frame,
    canvas,
    canvasWidth: 0,
    canvasHeight: 0,
    card,
    tilt,
    borderWidth,
    background,
  };
}

export const CARD_STYLES: { id: CardStyle; name: string; radius: number; shadow: number; borderWidth: number }[] = [
  { id: "default", name: "Default", radius: 22, shadow: 36, borderWidth: 0 },
  { id: "glass-light", name: "Glass Light", radius: 28, shadow: 28, borderWidth: 0 },
  { id: "glass-dark", name: "Glass Dark", radius: 28, shadow: 34, borderWidth: 0 },
  { id: "liquid", name: "Liquid Glass", radius: 32, shadow: 22, borderWidth: 0 },
  { id: "inset-light", name: "Inset Light", radius: 24, shadow: 8, borderWidth: 0 },
  { id: "inset-dark", name: "Inset Dark", radius: 24, shadow: 8, borderWidth: 0 },
  { id: "outline", name: "Outline", radius: 18, shadow: 0, borderWidth: 3 },
  { id: "border", name: "Border", radius: 16, shadow: 18, borderWidth: 8 },
];

export const LAYOUTS: { id: string; name: string; style: Style }[] = [
  { id: "daylight", name: "Daylight", style: makeStyle(78, 28, 42, "none", { kind: "gradient", from: "#F0F0EB", mid: "#CCE0F0", to: "#F2C2B2", angle: 135 }, "16:9", "default", 8) },
  { id: "iris", name: "Iris", style: makeStyle(84, 26, 48, "none", { kind: "gradient", from: "#FA4F94", mid: "#6652F2", to: "#4AD6CC", angle: 135 }, "16:9", "default", 12) },
  { id: "dusk", name: "Dusk city", style: makeStyle(72, 24, 40, "none", { kind: "wallpaper", id: "dusk" }, "16:9", "glass-light", 10) },
  { id: "night", name: "Night", style: makeStyle(76, 28, 36, "none", { kind: "wallpaper", id: "night" }, "4:3", "glass-dark", 14) },
  { id: "sorbet", name: "Sorbet", style: makeStyle(88, 32, 30, "none", { kind: "wallpaper", id: "sorbet" }, "auto", "liquid", 6) },
  { id: "hills", name: "Hills", style: makeStyle(80, 22, 38, "none", { kind: "wallpaper", id: "hills" }, "3:2", "default", 11) },
  { id: "harbour", name: "Harbour", style: makeStyle(70, 18, 44, "none", { kind: "wallpaper", id: "harbour" }, "16:9", "inset-light", 9) },
  { id: "ink", name: "Ink", style: makeStyle(64, 14, 20, "none", { kind: "color", color: "#111827" }, "1:1", "outline", 0) },
  { id: "studio", name: "Studio", style: makeStyle(90, 20, 46, "browser", { kind: "gradient", from: "#DEF2F0", mid: "#75C4DB", to: "#4087ED", angle: 135 }, "16:9", "default", 7) },
  { id: "aurora", name: "Aurora", style: makeStyle(82, 30, 34, "none", { kind: "wallpaper", id: "aurora" }, "16:9", "glass-dark", 13) },
];

export const PRESETS: Preset[] = [
  {
    id: "clean",
    name: "Clean",
    style: makeStyle(56, 14, 28, "none", { kind: "color", color: "#FFFFFF" }),
  },
  {
    id: "studio",
    name: "Studio",
    style: makeStyle(80, 16, 42, "none", { kind: "gradient", from: "#F0F0EB", mid: "#CCE0F0", to: "#F2C2B2", angle: 135 }),
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
    style: makeStyle(84, 24, 34, "none", { kind: "gradient", from: "#FA9EC4", mid: "#FAD178", to: "#6BB5F5", angle: 315 }),
  },
  {
    id: "signal",
    name: "Signal",
    style: makeStyle(76, 18, 48, "none", { kind: "gradient", from: "#0A0D80", mid: "#4230ED", to: "#6BABFA", angle: 153 }),
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
    const mid = background.mid ? `, ${background.mid}` : "";
    return `linear-gradient(${background.angle}deg, ${background.from}${mid}, ${background.to})`;
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
