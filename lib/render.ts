import { annotationBounds, handlesFor, normalizeRect } from "./geometry";
import { activeCrop, compositionOf, displayName } from "./layout";
import { drawScene, isScene } from "./scenes";
import type { Annotation, Background, Doc, Rect, ShapeAnnotation, WallpaperId } from "./types";

export type RenderOptions = {
  fontFamily?: string;
  interactive?: boolean;
  zoom?: number;
  draft?: Annotation | null;
  cropDraft?: Rect | null;
  hideTextId?: string | null;
  background?: boolean;
};

const tileCache = new Map<WallpaperId, HTMLCanvasElement>();

export function renderComposition(
  ctx: CanvasRenderingContext2D,
  doc: Doc,
  options: RenderOptions = {},
) {
  const fontFamily = options.fontFamily ?? "Geist, ui-sans-serif, sans-serif";
  const zoom = options.zoom && options.zoom > 0 ? options.zoom : 1;
  const composition = compositionOf(doc);

  ctx.save();
  ctx.clearRect(0, 0, composition.compW, composition.compH);
  if (options.background !== false) {
    paintBackground(ctx, doc.style.background, composition.compW, composition.compH);
  }

  paintCard(ctx, composition.window, doc.style);

  if (!doc.image) {
    ctx.restore();
    return;
  }

  const crop = activeCrop(doc)!;
  const radius = doc.style.radius;
  const framed = doc.style.frame !== "none";

  if (doc.style.frame === "browser") {
    drawBrowserChrome(ctx, composition.window, radius, doc.image.name, fontFamily);
  } else if (doc.style.frame === "desktop") {
    drawDesktopChrome(ctx, composition.window, radius, doc.image.name, fontFamily);
  }

  ctx.save();
  clipImage(ctx, composition.image, radius, framed);
  ctx.imageSmoothingEnabled = true;
  ctx.imageSmoothingQuality = "high";
  ctx.drawImage(
    doc.image.bitmap,
    crop.x,
    crop.y,
    crop.w,
    crop.h,
    composition.image.x,
    composition.image.y,
    composition.image.w,
    composition.image.h,
  );

  ctx.translate(composition.image.x - crop.x, composition.image.y - crop.y);
  const annotations = options.draft ? [...doc.annotations, options.draft] : doc.annotations;

  for (const annotation of annotations) {
    if (annotation.type === "pixelate" || annotation.type === "blur") {
      drawRedaction(ctx, doc.image.bitmap, annotation);
    }
  }
  for (const annotation of annotations) {
    if (annotation.type === "pixelate" || annotation.type === "blur") continue;
    if (annotation.type === "text" && annotation.id === options.hideTextId) continue;
    drawAnnotation(ctx, annotation, fontFamily);
  }

  if (options.interactive && options.cropDraft) {
    drawCropOverlay(ctx, crop, options.cropDraft, zoom);
  }
  if (options.interactive && doc.selectedId) {
    const selected = annotations.find((annotation) => annotation.id === doc.selectedId);
    if (selected && selected.id !== options.draft?.id) drawSelection(ctx, selected, zoom);
  }
  ctx.restore();

  paintCardEdge(ctx, composition.window, doc.style);
  ctx.restore();
}

export function paintBackground(ctx: CanvasRenderingContext2D, background: Background, width: number, height: number) {
  if (background.kind === "color") {
    if (background.color === "transparent") return;
    ctx.fillStyle = background.color;
    ctx.fillRect(0, 0, width, height);
    return;
  }
  if (background.kind === "gradient") {
    const radians = ((background.angle - 90) * Math.PI) / 180;
    const cx = width / 2;
    const cy = height / 2;
    const length = Math.abs(width * Math.cos(radians)) + Math.abs(height * Math.sin(radians));
    const dx = (Math.cos(radians) * length) / 2;
    const dy = (Math.sin(radians) * length) / 2;
    const gradient = ctx.createLinearGradient(cx - dx, cy - dy, cx + dx, cy + dy);
    gradient.addColorStop(0, background.from);
    gradient.addColorStop(1, background.to);
    ctx.fillStyle = gradient;
    ctx.fillRect(0, 0, width, height);
    return;
  }
  if (background.id === "mesh") {
    drawMesh(ctx, width, height);
    return;
  }
  if (isScene(background.id)) {
    drawScene(ctx, background.id, width, height);
    return;
  }
  const pattern = wallpaperPattern(ctx, background.id);
  if (!pattern) return;
  ctx.fillStyle = pattern;
  ctx.fillRect(0, 0, width, height);
}

function wallpaperPattern(ctx: CanvasRenderingContext2D, id: WallpaperId) {
  let tile = tileCache.get(id);
  if (!tile) {
    tile = document.createElement("canvas");
    const size = id === "stripes" || id === "diagonal" ? 16 : 18;
    tile.width = size;
    tile.height = size;
    const g = tile.getContext("2d");
    if (!g) return null;
    paintTile(g, id, size);
    tileCache.set(id, tile);
  }
  return ctx.createPattern(tile, "repeat");
}

function paintTile(g: CanvasRenderingContext2D, id: WallpaperId, size: number) {
  if (id === "dots") {
    g.fillStyle = "#E8E6E3";
    g.fillRect(0, 0, size, size);
    g.fillStyle = "#C9C5BF";
    g.beginPath();
    g.arc(size / 2, size / 2, 1.15, 0, Math.PI * 2);
    g.fill();
  } else if (id === "grid") {
    g.fillStyle = "#F7F7F7";
    g.fillRect(0, 0, size, size);
    g.strokeStyle = "#E4E4E4";
    g.strokeRect(0.5, 0.5, size, size);
  } else if (id === "diagonal") {
    g.fillStyle = "#EEF2FF";
    g.fillRect(0, 0, size, size);
    g.strokeStyle = "#D9E2FF";
    g.beginPath();
    g.moveTo(0, size);
    g.lineTo(size, 0);
    g.stroke();
  } else if (id === "stripes") {
    g.fillStyle = "#F4F1EC";
    g.fillRect(0, 0, size, size);
    g.fillStyle = "#EBE4D8";
    g.fillRect(0, 0, size, size / 2);
  } else if (id === "cross") {
    g.fillStyle = "#F4F7FB";
    g.fillRect(0, 0, size, size);
    g.strokeStyle = "#DBE3F0";
    g.beginPath();
    g.moveTo(0, 0.5);
    g.lineTo(size, 0.5);
    g.moveTo(0.5, 0);
    g.lineTo(0.5, size);
    g.stroke();
  }
}

function drawMesh(ctx: CanvasRenderingContext2D, width: number, height: number) {
  ctx.fillStyle = "#F6F7F8";
  ctx.fillRect(0, 0, width, height);
  const blobs = [
    { x: 0.2, y: 0.2, color: "rgba(253, 226, 228, 0.95)" },
    { x: 0.82, y: 0.18, color: "rgba(219, 234, 254, 0.95)" },
    { x: 0.55, y: 0.85, color: "rgba(209, 250, 229, 0.9)" },
    { x: 0.1, y: 0.75, color: "rgba(254, 243, 199, 0.7)" },
  ];
  for (const blob of blobs) {
    const gradient = ctx.createRadialGradient(
      width * blob.x,
      height * blob.y,
      0,
      width * blob.x,
      height * blob.y,
      Math.max(width, height) * 0.45,
    );
    gradient.addColorStop(0, blob.color);
    gradient.addColorStop(1, "rgba(255,255,255,0)");
    ctx.fillStyle = gradient;
    ctx.fillRect(0, 0, width, height);
  }
}

function paintCard(ctx: CanvasRenderingContext2D, rect: Rect, style: Doc["style"]) {
  const radius = style.radius;
  const card = style.card ?? "default";
  ctx.save();
  traceRoundRect(ctx, rect.x, rect.y, rect.w, rect.h, radius);
  if (card === "outline") {
    ctx.strokeStyle = "#222222";
    ctx.lineWidth = style.borderWidth || 3;
    ctx.stroke();
    ctx.restore();
    return;
  }
  if (style.shadow > 0 && card !== "inset-light" && card !== "inset-dark") applyShadow(ctx, style.shadow);
  if (card === "glass-light") ctx.fillStyle = "rgba(255,255,255,0.72)";
  else if (card === "glass-dark") ctx.fillStyle = "rgba(16,18,27,0.62)";
  else if (card === "liquid") ctx.fillStyle = "rgba(255,255,255,0.4)";
  else if (card === "inset-dark") ctx.fillStyle = "#16171c";
  else if (card === "inset-light") ctx.fillStyle = "#f3f3f4";
  else ctx.fillStyle = style.frame === "none" ? "#FFFFFF" : "#F4F4F4";
  ctx.fill();
  ctx.shadowColor = "transparent";
  if (card === "glass-light" || card === "liquid" || card === "glass-dark") {
    ctx.strokeStyle = card === "glass-dark" ? "rgba(255,255,255,0.28)" : "rgba(255,255,255,0.85)";
    ctx.lineWidth = 2;
    traceRoundRect(ctx, rect.x + 1, rect.y + 1, rect.w - 2, rect.h - 2, Math.max(0, radius - 1));
    ctx.stroke();
  } else if (card === "border") {
    ctx.strokeStyle = "#171717";
    ctx.lineWidth = style.borderWidth || 8;
    traceRoundRect(ctx, rect.x, rect.y, rect.w, rect.h, radius);
    ctx.stroke();
  } else if (card === "inset-light" || card === "inset-dark") {
    ctx.save();
    traceRoundRect(ctx, rect.x, rect.y, rect.w, rect.h, radius);
    ctx.clip();
    ctx.strokeStyle = card === "inset-dark" ? "rgba(0,0,0,0.65)" : "rgba(0,0,0,0.16)";
    ctx.lineWidth = 18;
    traceRoundRect(ctx, rect.x + 1, rect.y + 1, rect.w - 2, rect.h - 2, radius);
    ctx.stroke();
    ctx.restore();
  }
  ctx.restore();
}

function paintCardEdge(ctx: CanvasRenderingContext2D, rect: Rect, style: Doc["style"]) {
  const card = style.card ?? "default";
  const radius = style.radius;
  ctx.save();
  if (card === "outline" || card === "border") {
    ctx.strokeStyle = "#171717";
    ctx.lineWidth = card === "outline" ? style.borderWidth || 3 : style.borderWidth || 8;
    traceRoundRect(ctx, rect.x, rect.y, rect.w, rect.h, radius);
    ctx.stroke();
  } else if (card === "glass-light" || card === "liquid" || card === "glass-dark") {
    ctx.strokeStyle = card === "glass-dark" ? "rgba(255,255,255,0.45)" : "rgba(255,255,255,0.9)";
    ctx.lineWidth = 2;
    traceRoundRect(ctx, rect.x + 1.5, rect.y + 1.5, rect.w - 3, rect.h - 3, Math.max(0, radius - 1));
    ctx.stroke();
  } else {
    ctx.strokeStyle = "rgba(0, 0, 0, 0.12)";
    ctx.lineWidth = 1;
    traceRoundRect(ctx, rect.x + 0.5, rect.y + 0.5, rect.w - 1, rect.h - 1, Math.max(0, radius - 0.5));
    ctx.stroke();
  }
  ctx.restore();
}

function applyShadow(ctx: CanvasRenderingContext2D, intensity: number) {
  const amount = intensity / 100;
  ctx.shadowColor = `rgba(20, 20, 20, ${0.05 + amount * 0.4})`;
  ctx.shadowBlur = 8 + amount * 72;
  ctx.shadowOffsetY = 2 + amount * 26;
}

function drawBrowserChrome(
  ctx: CanvasRenderingContext2D,
  windowRect: Rect,
  radius: number,
  filename: string,
  fontFamily: string,
) {
  const chrome = windowRect.h > 0 ? Math.min(46, windowRect.h) : 46;
  ctx.save();
  traceRoundRect(ctx, windowRect.x, windowRect.y, windowRect.w, windowRect.h, radius);
  ctx.clip();
  ctx.fillStyle = "#F3F3F3";
  ctx.fillRect(windowRect.x, windowRect.y, windowRect.w, chrome);
  ctx.strokeStyle = "#E3E3E3";
  ctx.beginPath();
  ctx.moveTo(windowRect.x, windowRect.y + chrome + 0.5);
  ctx.lineTo(windowRect.x + windowRect.w, windowRect.y + chrome + 0.5);
  ctx.stroke();

  ["#FF5F57", "#FEBC2E", "#28C840"].forEach((color, index) => {
    ctx.beginPath();
    ctx.arc(windowRect.x + 20 + index * 16, windowRect.y + chrome / 2, 5.5, 0, Math.PI * 2);
    ctx.fillStyle = color;
    ctx.fill();
  });

  const pillWidth = Math.min(280, Math.max(80, windowRect.w * 0.42));
  const pillHeight = 22;
  const pillX = windowRect.x + (windowRect.w - pillWidth) / 2;
  const pillY = windowRect.y + (chrome - pillHeight) / 2;
  if (windowRect.w > 180) {
    traceRoundRect(ctx, pillX, pillY, pillWidth, pillHeight, 6);
    ctx.fillStyle = "#FFFFFF";
    ctx.fill();
    ctx.fillStyle = "#8A8A8A";
    ctx.font = `12px ${fontFamily}`;
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.fillText(fitText(ctx, displayName(filename), pillWidth - 20), windowRect.x + windowRect.w / 2, windowRect.y + chrome / 2 + 0.5);
  }
  ctx.restore();
}

function drawDesktopChrome(
  ctx: CanvasRenderingContext2D,
  windowRect: Rect,
  radius: number,
  filename: string,
  fontFamily: string,
) {
  const chrome = 46;
  ctx.save();
  traceRoundRect(ctx, windowRect.x, windowRect.y, windowRect.w, windowRect.h, radius);
  ctx.clip();
  ctx.fillStyle = "#ECECEC";
  ctx.fillRect(windowRect.x, windowRect.y, windowRect.w, chrome);
  ctx.strokeStyle = "#DEDEDE";
  ctx.beginPath();
  ctx.moveTo(windowRect.x, windowRect.y + chrome + 0.5);
  ctx.lineTo(windowRect.x + windowRect.w, windowRect.y + chrome + 0.5);
  ctx.stroke();
  ["#FF5F57", "#FEBC2E", "#28C840"].forEach((color, index) => {
    ctx.beginPath();
    ctx.arc(windowRect.x + 18 + index * 15, windowRect.y + chrome / 2, 5, 0, Math.PI * 2);
    ctx.fillStyle = color;
    ctx.fill();
  });
  ctx.fillStyle = "#4B4B4B";
  ctx.font = `600 13px ${fontFamily}`;
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.fillText(fitText(ctx, displayName(filename), windowRect.w - 120), windowRect.x + windowRect.w / 2, windowRect.y + chrome / 2);
  ctx.restore();
}

function clipImage(ctx: CanvasRenderingContext2D, image: Rect, radius: number, framed: boolean) {
  const r = Math.max(0, Math.min(radius, image.w / 2, image.h / 2));
  ctx.beginPath();
  if (!framed || r === 0) {
    traceRoundRect(ctx, image.x, image.y, image.w, image.h, framed ? 0 : r);
  } else {
    const { x, y, w, h } = image;
    ctx.moveTo(x, y);
    ctx.lineTo(x + w, y);
    ctx.lineTo(x + w, y + h - r);
    ctx.arcTo(x + w, y + h, x + w - r, y + h, r);
    ctx.arcTo(x, y + h, x, y + h - r, r);
    ctx.closePath();
  }
  ctx.clip();
}

function drawRedaction(ctx: CanvasRenderingContext2D, bitmap: ImageBitmap, annotation: ShapeAnnotation) {
  const rect = normalizeRect(annotation.x, annotation.y, annotation.w, annotation.h);
  if (rect.w < 2 || rect.h < 2) return;
  if (annotation.type === "pixelate") {
    const block = Math.max(4, annotation.amount || 14);
    const cols = Math.max(1, Math.round(rect.w / block));
    const rows = Math.max(1, Math.round(rect.h / block));
    const small = document.createElement("canvas");
    small.width = cols;
    small.height = rows;
    const g = small.getContext("2d");
    if (!g) return;
    g.drawImage(bitmap, rect.x, rect.y, rect.w, rect.h, 0, 0, cols, rows);
    ctx.save();
    ctx.imageSmoothingEnabled = false;
    ctx.drawImage(small, rect.x, rect.y, rect.w, rect.h);
    ctx.restore();
    return;
  }
  const radius = Math.max(2, annotation.amount || 12);
  const pad = Math.ceil(radius * 2);
  const blurred = document.createElement("canvas");
  blurred.width = Math.ceil(rect.w) + pad * 2;
  blurred.height = Math.ceil(rect.h) + pad * 2;
  const g = blurred.getContext("2d");
  if (!g) return;
  g.filter = `blur(${radius}px)`;
  g.drawImage(
    bitmap,
    rect.x - pad,
    rect.y - pad,
    rect.w + pad * 2,
    rect.h + pad * 2,
    0,
    0,
    blurred.width,
    blurred.height,
  );
  ctx.drawImage(blurred, pad, pad, rect.w, rect.h, rect.x, rect.y, rect.w, rect.h);
}

function drawAnnotation(ctx: CanvasRenderingContext2D, annotation: Annotation, fontFamily: string) {
  ctx.save();
  ctx.lineJoin = "round";
  ctx.lineCap = "round";
  ctx.strokeStyle = annotation.color;
  ctx.fillStyle = annotation.color;
  ctx.lineWidth = annotation.strokeWidth;

  if (annotation.type === "rect" || annotation.type === "rect-fill") {
    const rect = normalizeRect(annotation.x, annotation.y, annotation.w, annotation.h);
    if (annotation.type === "rect-fill") {
      ctx.save();
      ctx.globalAlpha = 0.22;
      ctx.fillRect(rect.x, rect.y, rect.w, rect.h);
      ctx.restore();
    }
    ctx.strokeRect(rect.x, rect.y, rect.w, rect.h);
  } else if (annotation.type === "circle") {
    const rect = normalizeRect(annotation.x, annotation.y, annotation.w, annotation.h);
    ctx.beginPath();
    ctx.ellipse(rect.x + rect.w / 2, rect.y + rect.h / 2, rect.w / 2, rect.h / 2, 0, 0, Math.PI * 2);
    ctx.stroke();
  } else if (annotation.type === "line" || annotation.type === "arrow") {
    ctx.beginPath();
    ctx.moveTo(annotation.x, annotation.y);
    ctx.lineTo(annotation.x2, annotation.y2);
    ctx.stroke();
    if (annotation.type === "arrow") drawArrowHead(ctx, annotation.x, annotation.y, annotation.x2, annotation.y2, annotation.strokeWidth);
  } else if (annotation.type === "draw") {
    if (annotation.points.length > 1) {
      ctx.beginPath();
      ctx.moveTo(annotation.points[0].x, annotation.points[0].y);
      for (const point of annotation.points.slice(1)) ctx.lineTo(point.x, point.y);
      ctx.stroke();
    }
  } else if (annotation.type === "text") {
    ctx.font = `${annotation.fontSize}px ${fontFamily}`;
    ctx.textBaseline = "top";
    ctx.textAlign = "left";
    annotation.text.split("\n").forEach((line, index) => {
      ctx.fillText(line, annotation.x, annotation.y + index * annotation.fontSize * 1.25);
    });
  } else if (annotation.type === "marker") {
    ctx.beginPath();
    ctx.arc(annotation.x, annotation.y, 15, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = readableInk(annotation.color);
    ctx.font = `600 13px ${fontFamily}`;
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.fillText(String(annotation.n), annotation.x, annotation.y + 0.5);
  }
  ctx.restore();
}

function drawArrowHead(
  ctx: CanvasRenderingContext2D,
  x1: number,
  y1: number,
  x2: number,
  y2: number,
  strokeWidth: number,
) {
  const angle = Math.atan2(y2 - y1, x2 - x1);
  const length = 8 + strokeWidth * 2.2;
  ctx.beginPath();
  ctx.moveTo(x2, y2);
  ctx.lineTo(x2 - length * Math.cos(angle - 0.42), y2 - length * Math.sin(angle - 0.42));
  ctx.lineTo(x2 - length * Math.cos(angle + 0.42), y2 - length * Math.sin(angle + 0.42));
  ctx.closePath();
  ctx.fill();
}

function drawCropOverlay(ctx: CanvasRenderingContext2D, visible: Rect, draft: Rect, zoom: number) {
  const rect = normalizeRect(draft.x, draft.y, draft.w, draft.h);
  ctx.save();
  ctx.beginPath();
  ctx.rect(visible.x, visible.y, visible.w, visible.h);
  ctx.rect(rect.x, rect.y, rect.w, rect.h);
  ctx.fillStyle = "rgba(20, 20, 20, 0.45)";
  ctx.fill("evenodd");
  ctx.strokeStyle = "#3478F6";
  ctx.lineWidth = 1.5 / zoom;
  ctx.setLineDash([5 / zoom, 4 / zoom]);
  ctx.strokeRect(rect.x, rect.y, rect.w, rect.h);
  ctx.restore();
}

function drawSelection(ctx: CanvasRenderingContext2D, annotation: Annotation, zoom: number) {
  const bounds = annotationBounds(annotation);
  ctx.save();
  ctx.strokeStyle = "#3478F6";
  ctx.lineWidth = 1 / zoom;
  ctx.setLineDash([4 / zoom, 3 / zoom]);
  if (annotation.type === "marker") {
    ctx.beginPath();
    ctx.arc(annotation.x, annotation.y, 18, 0, Math.PI * 2);
    ctx.stroke();
  } else {
    ctx.strokeRect(bounds.x - 2 / zoom, bounds.y - 2 / zoom, bounds.w + 4 / zoom, bounds.h + 4 / zoom);
  }
  ctx.setLineDash([]);
  const size = 8 / zoom;
  ctx.fillStyle = "#FFFFFF";
  ctx.lineWidth = 1 / zoom;
  for (const handle of handlesFor(annotation)) {
    ctx.fillRect(handle.x - size / 2, handle.y - size / 2, size, size);
    ctx.strokeRect(handle.x - size / 2, handle.y - size / 2, size, size);
  }
  ctx.restore();
}

function traceRoundRect(
  ctx: CanvasRenderingContext2D,
  x: number,
  y: number,
  w: number,
  h: number,
  r: number,
) {
  const radius = Math.max(0, Math.min(r, Math.abs(w) / 2, Math.abs(h) / 2));
  ctx.beginPath();
  ctx.moveTo(x + radius, y);
  ctx.arcTo(x + w, y, x + w, y + h, radius);
  ctx.arcTo(x + w, y + h, x, y + h, radius);
  ctx.arcTo(x, y + h, x, y, radius);
  ctx.arcTo(x, y, x + w, y, radius);
  ctx.closePath();
}

function fitText(ctx: CanvasRenderingContext2D, text: string, maxWidth: number) {
  if (ctx.measureText(text).width <= maxWidth) return text;
  let value = text;
  while (value.length > 1 && ctx.measureText(`${value}…`).width > maxWidth) value = value.slice(0, -1);
  return `${value}…`;
}

function readableInk(color: string) {
  const hex = color.replace("#", "");
  if (hex.length !== 6) return "#FFFFFF";
  const r = Number.parseInt(hex.slice(0, 2), 16);
  const g = Number.parseInt(hex.slice(2, 4), 16);
  const b = Number.parseInt(hex.slice(4, 6), 16);
  return r * 0.2126 + g * 0.7152 + b * 0.0722 > 170 ? "#222222" : "#FFFFFF";
}
