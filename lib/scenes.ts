import type { WallpaperId } from "./types";

export const SCENE_IDS = ["dusk", "night", "harbour", "hills", "aurora", "sorbet"] as const;

export type SceneId = (typeof SCENE_IDS)[number];

export function isScene(id: WallpaperId): id is SceneId {
  return (SCENE_IDS as readonly string[]).includes(id);
}

type Tower = { x: number; w: number; h: number };

const SKYLINE: Tower[] = [
  { x: 0, w: 0.07, h: 0.28 },
  { x: 0.07, w: 0.045, h: 0.18 },
  { x: 0.115, w: 0.1, h: 0.46 },
  { x: 0.215, w: 0.06, h: 0.26 },
  { x: 0.275, w: 0.05, h: 0.16 },
  { x: 0.325, w: 0.13, h: 0.38 },
  { x: 0.455, w: 0.035, h: 0.56 },
  { x: 0.49, w: 0.08, h: 0.3 },
  { x: 0.57, w: 0.11, h: 0.42 },
  { x: 0.68, w: 0.055, h: 0.22 },
  { x: 0.735, w: 0.09, h: 0.36 },
  { x: 0.825, w: 0.06, h: 0.2 },
  { x: 0.885, w: 0.115, h: 0.32 },
];

const STARS: [number, number, number][] = [
  [0.06, 0.08, 1.1],
  [0.14, 0.16, 0.7],
  [0.22, 0.05, 1.3],
  [0.31, 0.12, 0.6],
  [0.4, 0.07, 0.9],
  [0.48, 0.18, 0.5],
  [0.57, 0.06, 1.2],
  [0.66, 0.14, 0.7],
  [0.74, 0.04, 0.8],
  [0.83, 0.11, 1.4],
  [0.91, 0.07, 0.6],
  [0.18, 0.28, 0.5],
  [0.35, 0.22, 0.4],
  [0.62, 0.24, 0.6],
  [0.88, 0.22, 0.5],
];

export function drawScene(ctx: CanvasRenderingContext2D, id: SceneId, width: number, height: number) {
  switch (id) {
    case "dusk":
      vertical(ctx, width, height, [
        [0, "#FF8A5B"],
        [0.42, "#F6B7C5"],
        [0.72, "#7C6BD4"],
        [1, "#2A2148"],
      ]);
      glow(ctx, width, height, 0.22, 0.62, 0.42, "#FFB088", 0.95);
      disc(ctx, width, height, 0.22, 0.6, 0.055, "#FFE1C4");
      skyline(ctx, width, height, height, "#1C1430", "#2C2144", "#F8E2A0", 3, 1);
      return;
    case "night":
      vertical(ctx, width, height, [
        [0, "#070B18"],
        [0.55, "#1A2744"],
        [1, "#0A0E1A"],
      ]);
      stars(ctx, width, height);
      glow(ctx, width, height, 0.8, 0.16, 0.22, "#D7E2FF", 0.45);
      disc(ctx, width, height, 0.8, 0.16, 0.04, "#F7F3E8");
      skyline(ctx, width, height, height, "#070910", "#141A28", "#FFE08A", 4, 2);
      return;
    case "harbour":
      drawHarbour(ctx, width, height);
      return;
    case "hills":
      vertical(ctx, width, height, [
        [0, "#FFD7C2"],
        [0.45, "#F7A58A"],
        [1, "#E7C4EE"],
      ]);
      glow(ctx, width, height, 0.72, 0.3, 0.28, "#FFE7C2", 0.9);
      disc(ctx, width, height, 0.72, 0.3, 0.05, "#FFF6E8");
      hill(ctx, width, height, 0.58, 0.06, 1.4, 0.4, "#C47B9B");
      hill(ctx, width, height, 0.7, 0.05, 1.8, 1.7, "#8E5A78");
      hill(ctx, width, height, 0.84, 0.045, 1.2, 0.2, "#3D2A3E");
      return;
    case "aurora":
      vertical(ctx, width, height, [
        [0, "#07111F"],
        [0.6, "#10243A"],
        [1, "#071018"],
      ]);
      stars(ctx, width, height);
      glow(ctx, width, height, 0.28, 0.42, 0.5, "#5EEAD4", 0.55);
      glow(ctx, width, height, 0.72, 0.36, 0.48, "#A78BFA", 0.5);
      glow(ctx, width, height, 0.5, 0.55, 0.36, "#34D399", 0.35);
      band(ctx, width, height, 0.34, 0.07, 1.6, 0.4, "#5EEAD4", 0.16, 0.55);
      band(ctx, width, height, 0.46, 0.08, 1.3, 2.1, "#67E8F9", 0.14, 0.4);
      band(ctx, width, height, 0.4, 0.06, 2.1, 1.1, "#C4B5FD", 0.12, 0.45);
      hill(ctx, width, height, 0.86, 0.035, 1.5, 0.6, "#071018");
      return;
    case "sorbet":
      vertical(ctx, width, height, [
        [0, "#FFE4E6"],
        [0.5, "#FFF6E8"],
        [1, "#E0F2FE"],
      ]);
      glow(ctx, width, height, 0.16, 0.22, 0.55, "#FB7185", 0.9);
      glow(ctx, width, height, 0.8, 0.16, 0.5, "#C4B5FD", 0.92);
      glow(ctx, width, height, 0.58, 0.78, 0.55, "#6EE7B7", 0.85);
      glow(ctx, width, height, 0.18, 0.76, 0.42, "#FDE68A", 0.8);
      glow(ctx, width, height, 0.86, 0.62, 0.4, "#7DD3FC", 0.75);
      glow(ctx, width, height, 0.46, 0.4, 0.32, "#F9A8D4", 0.7);
      return;
  }
}

function drawHarbour(ctx: CanvasRenderingContext2D, width: number, height: number) {
  const ground = height * 0.58;
  vertical(ctx, width, height, [
    [0, "#F3C7A2"],
    [0.4, "#8EADD4"],
    [1, "#1B3A5C"],
  ]);
  const water = ctx.createLinearGradient(0, ground, 0, height);
  water.addColorStop(0, "#245074");
  water.addColorStop(1, "#0E2438");
  ctx.fillStyle = water;
  ctx.fillRect(0, ground, width, height - ground);
  glow(ctx, width, height, 0.7, 0.42, 0.24, "#F8D7B0", 0.8);
  disc(ctx, width, height, 0.7, 0.4, 0.035, "#FFF1DE");
  skyline(ctx, width, height, ground, "#101820", "#1C2A3A", "#F6E7B2", 4, 3);
  ctx.save();
  ctx.globalAlpha = 0.32;
  ctx.translate(0, ground);
  ctx.scale(1, -0.7);
  ctx.translate(0, -ground);
  skyline(ctx, width, height, ground, "#101820", "#1C2A3A", "#F6E7B2", 4, 3);
  ctx.restore();
  ctx.fillStyle = "rgba(14, 36, 56, 0.28)";
  for (let y = ground + 6, i = 0; y < height; y += 12, i += 1) {
    ctx.fillRect(0, y, width, i % 2 === 0 ? 2 : 5);
  }
  ctx.fillStyle = "rgba(255, 236, 214, 0.55)";
  ctx.fillRect(0, ground - 1, width, 1.5);
}

function skyline(
  ctx: CanvasRenderingContext2D,
  width: number,
  height: number,
  ground: number,
  color: string,
  alt: string,
  light: string,
  every: number,
  seed: number,
) {
  SKYLINE.forEach((tower, index) => {
    const bw = width * Math.max(0.02, tower.w - 0.012);
    const bh = height * tower.h;
    const bx = width * tower.x;
    const by = ground - bh;
    ctx.fillStyle = index % 2 === 0 ? color : alt;
    ctx.fillRect(bx, by, bw, bh);
    if (tower.h > 0.4) {
      const capW = bw * 0.55;
      const capH = bh * 0.12;
      ctx.fillRect(bx + (bw - capW) / 2, by - capH, capW, capH);
      ctx.fillRect(bx + bw / 2 - 1, by - capH - bh * 0.08, 2, bh * 0.08);
    }
    windows(ctx, bx, by, bw, bh, light, every, seed);
  });
}

function windows(
  ctx: CanvasRenderingContext2D,
  bx: number,
  by: number,
  bw: number,
  bh: number,
  light: string,
  every: number,
  seed: number,
) {
  const gapX = Math.max(5, bw * 0.16);
  const gapY = Math.max(6, gapX * 1.15);
  const winW = Math.max(1.4, gapX * 0.42);
  const winH = winW * 1.25;
  let row = 0;
  for (let y = by + bh * 0.08; y + winH < by + bh - 2; y += gapY) {
    let col = 0;
    for (let x = bx + bw * 0.16; x + winW < bx + bw * 0.88; x += gapX) {
      if ((col * 3 + row * 5 + seed) % every === 0) {
        const previous = ctx.globalAlpha;
        ctx.fillStyle = light;
        ctx.globalAlpha = previous * 0.92;
        ctx.fillRect(x, y, winW, winH);
        ctx.globalAlpha = previous;
      }
      col += 1;
    }
    row += 1;
  }
}

function stars(ctx: CanvasRenderingContext2D, width: number, height: number) {
  ctx.fillStyle = "rgba(255,255,255,0.88)";
  for (const star of STARS) {
    const r = (star[2] * Math.min(width, height)) / 420;
    ctx.beginPath();
    ctx.arc(width * star[0], height * star[1], r, 0, Math.PI * 2);
    ctx.fill();
  }
}

function vertical(
  ctx: CanvasRenderingContext2D,
  width: number,
  height: number,
  stops: [number, string][],
) {
  const gradient = ctx.createLinearGradient(0, 0, 0, height);
  for (const stop of stops) gradient.addColorStop(stop[0], stop[1]);
  ctx.fillStyle = gradient;
  ctx.fillRect(0, 0, width, height);
}

function glow(
  ctx: CanvasRenderingContext2D,
  width: number,
  height: number,
  x: number,
  y: number,
  radius: number,
  color: string,
  alpha: number,
) {
  const cx = width * x;
  const cy = height * y;
  const r = Math.max(width, height) * radius;
  const gradient = ctx.createRadialGradient(cx, cy, 0, cx, cy, r);
  gradient.addColorStop(0, hexAlpha(color, alpha));
  gradient.addColorStop(1, hexAlpha(color, 0));
  ctx.fillStyle = gradient;
  ctx.fillRect(0, 0, width, height);
}

function disc(
  ctx: CanvasRenderingContext2D,
  width: number,
  height: number,
  x: number,
  y: number,
  radius: number,
  color: string,
) {
  const r = Math.min(width, height) * radius;
  ctx.fillStyle = color;
  ctx.beginPath();
  ctx.arc(width * x, height * y, r, 0, Math.PI * 2);
  ctx.fill();
}

function hill(
  ctx: CanvasRenderingContext2D,
  width: number,
  height: number,
  base: number,
  amp: number,
  waves: number,
  phase: number,
  color: string,
) {
  ctx.beginPath();
  const steps = 48;
  for (let i = 0; i <= steps; i += 1) {
    const t = i / steps;
    const y = height * base + Math.sin(t * waves * Math.PI * 2 + phase) * height * amp;
    if (i === 0) ctx.moveTo(width * t, y);
    else ctx.lineTo(width * t, y);
  }
  ctx.lineTo(width, height);
  ctx.lineTo(0, height);
  ctx.closePath();
  ctx.fillStyle = color;
  ctx.fill();
}

function band(
  ctx: CanvasRenderingContext2D,
  width: number,
  height: number,
  base: number,
  amp: number,
  waves: number,
  phase: number,
  color: string,
  thickness: number,
  alpha: number,
) {
  ctx.beginPath();
  const steps = 48;
  for (let i = 0; i <= steps; i += 1) {
    const t = i / steps;
    const y = height * base + Math.sin(t * waves * Math.PI * 2 + phase) * height * amp;
    if (i === 0) ctx.moveTo(width * t, y);
    else ctx.lineTo(width * t, y);
  }
  ctx.strokeStyle = hexAlpha(color, alpha);
  ctx.lineWidth = height * thickness;
  ctx.lineCap = "round";
  ctx.stroke();
}

function hexAlpha(hex: string, alpha: number) {
  const value = hex.replace("#", "");
  const number = Number.parseInt(value, 16);
  const r = (number >> 16) & 255;
  const g = (number >> 8) & 255;
  const b = number & 255;
  return `rgba(${r}, ${g}, ${b}, ${alpha})`;
}
