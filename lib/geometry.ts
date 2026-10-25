import type { Annotation, Handle, Rect, ShapeAnnotation } from "./types";

function isShape(annotation: Annotation): annotation is ShapeAnnotation {
  return (
    annotation.type === "rect" ||
    annotation.type === "rect-fill" ||
    annotation.type === "circle" ||
    annotation.type === "pixelate" ||
    annotation.type === "blur"
  );
}

export function clamp(n: number, min: number, max: number) {
  return Math.min(max, Math.max(min, n));
}

export function normalizeRect(x: number, y: number, w: number, h: number): Rect {
  return {
    x: w < 0 ? x + w : x,
    y: h < 0 ? y + h : y,
    w: Math.abs(w),
    h: Math.abs(h),
  };
}

export function clampRect(rect: Rect, bounds: Rect): Rect {
  const n = normalizeRect(rect.x, rect.y, rect.w, rect.h);
  const x1 = clamp(n.x, bounds.x, bounds.x + bounds.w);
  const y1 = clamp(n.y, bounds.y, bounds.y + bounds.h);
  const x2 = clamp(n.x + n.w, bounds.x, bounds.x + bounds.w);
  const y2 = clamp(n.y + n.h, bounds.y, bounds.y + bounds.h);
  return { x: x1, y: y1, w: Math.max(0, x2 - x1), h: Math.max(0, y2 - y1) };
}

export function almostSameRect(a: Rect, b: Rect, epsilon = 1.5) {
  return (
    Math.abs(a.x - b.x) < epsilon &&
    Math.abs(a.y - b.y) < epsilon &&
    Math.abs(a.w - b.w) < epsilon &&
    Math.abs(a.h - b.h) < epsilon
  );
}

export function pointInRect(x: number, y: number, rect: Rect, slop = 0) {
  return (
    x >= rect.x - slop &&
    y >= rect.y - slop &&
    x <= rect.x + rect.w + slop &&
    y <= rect.y + rect.h + slop
  );
}

export function distToSegment(
  px: number,
  py: number,
  x1: number,
  y1: number,
  x2: number,
  y2: number,
) {
  const dx = x2 - x1;
  const dy = y2 - y1;
  const len2 = dx * dx + dy * dy;
  const t = len2 === 0 ? 0 : clamp(((px - x1) * dx + (py - y1) * dy) / len2, 0, 1);
  return Math.hypot(px - (x1 + t * dx), py - (y1 + t * dy));
}

export function textWidth(text: string, fontSize: number) {
  const lines = text.length ? text.split("\n") : [""];
  let max = 1;
  for (const line of lines) max = Math.max(max, line.length);
  return Math.max(24, max * fontSize * 0.56);
}

export function textHeight(text: string, fontSize: number) {
  const lines = Math.max(1, (text.length ? text : " ").split("\n").length);
  return lines * fontSize * 1.25;
}

export function annotationBounds(annotation: Annotation): Rect {
  switch (annotation.type) {
    case "rect":
    case "rect-fill":
    case "circle":
    case "pixelate":
    case "blur":
      return normalizeRect(annotation.x, annotation.y, annotation.w, annotation.h);
    case "line":
    case "arrow": {
      const x = Math.min(annotation.x, annotation.x2);
      const y = Math.min(annotation.y, annotation.y2);
      return {
        x,
        y,
        w: Math.abs(annotation.x2 - annotation.x),
        h: Math.abs(annotation.y2 - annotation.y),
      };
    }
    case "draw": {
      if (annotation.points.length === 0) return { x: 0, y: 0, w: 0, h: 0 };
      let minX = Infinity;
      let minY = Infinity;
      let maxX = -Infinity;
      let maxY = -Infinity;
      for (const point of annotation.points) {
        minX = Math.min(minX, point.x);
        minY = Math.min(minY, point.y);
        maxX = Math.max(maxX, point.x);
        maxY = Math.max(maxY, point.y);
      }
      return { x: minX, y: minY, w: Math.max(1, maxX - minX), h: Math.max(1, maxY - minY) };
    }
    case "text":
      return {
        x: annotation.x,
        y: annotation.y,
        w: textWidth(annotation.text, annotation.fontSize),
        h: textHeight(annotation.text, annotation.fontSize),
      };
    case "marker":
      return { x: annotation.x - 16, y: annotation.y - 16, w: 32, h: 32 };
  }
}

export function isBigEnough(annotation: Annotation) {
  if (annotation.type === "line" || annotation.type === "arrow") {
    return Math.hypot(annotation.x2 - annotation.x, annotation.y2 - annotation.y) >= 4;
  }
  if (annotation.type === "draw") return annotation.points.length > 1;
  if (annotation.type === "text" || annotation.type === "marker") return true;
  if (!isShape(annotation)) return false;
  const rect = normalizeRect(annotation.x, annotation.y, annotation.w, annotation.h);
  return rect.w >= 4 && rect.h >= 4;
}

export function translateAnnotation(annotation: Annotation, dx: number, dy: number): Annotation {
  switch (annotation.type) {
    case "line":
    case "arrow":
      return {
        ...annotation,
        x: annotation.x + dx,
        y: annotation.y + dy,
        x2: annotation.x2 + dx,
        y2: annotation.y2 + dy,
      };
    case "draw":
      return {
        ...annotation,
        points: annotation.points.map((point) => ({ x: point.x + dx, y: point.y + dy })),
      };
    default:
      return { ...annotation, x: annotation.x + dx, y: annotation.y + dy };
  }
}

const BOX_HANDLES = ["nw", "n", "ne", "e", "se", "s", "sw", "w"] as const;

export function handlesFor(annotation: Annotation): { id: Handle; x: number; y: number }[] {
  if (annotation.type === "line" || annotation.type === "arrow") {
    return [
      { id: "start", x: annotation.x, y: annotation.y },
      { id: "end", x: annotation.x2, y: annotation.y2 },
    ];
  }
  if (!isShape(annotation)) return [];
  const bounds = normalizeRect(annotation.x, annotation.y, annotation.w, annotation.h);
  const midX = bounds.x + bounds.w / 2;
  const midY = bounds.y + bounds.h / 2;
  const right = bounds.x + bounds.w;
  const bottom = bounds.y + bounds.h;
  const positions: Record<(typeof BOX_HANDLES)[number], { x: number; y: number }> = {
    nw: { x: bounds.x, y: bounds.y },
    n: { x: midX, y: bounds.y },
    ne: { x: right, y: bounds.y },
    e: { x: right, y: midY },
    se: { x: right, y: bottom },
    s: { x: midX, y: bottom },
    sw: { x: bounds.x, y: bottom },
    w: { x: bounds.x, y: midY },
  };
  return BOX_HANDLES.map((id) => ({ id, ...positions[id] }));
}

export function hitHandle(annotation: Annotation, x: number, y: number, slop: number): Handle | null {
  const handles = handlesFor(annotation);
  for (let index = handles.length - 1; index >= 0; index -= 1) {
    const handle = handles[index];
    if (Math.abs(handle.x - x) <= slop && Math.abs(handle.y - y) <= slop) return handle.id;
  }
  return null;
}

export function hitAnnotation(annotation: Annotation, x: number, y: number, slop: number) {
  if (annotation.type === "line" || annotation.type === "arrow") {
    return (
      distToSegment(x, y, annotation.x, annotation.y, annotation.x2, annotation.y2) <=
      Math.max(slop, annotation.strokeWidth / 2 + 4)
    );
  }
  if (annotation.type === "draw") {
    const bounds = annotationBounds(annotation);
    if (!pointInRect(x, y, bounds, slop + 8)) return false;
    for (let index = 1; index < annotation.points.length; index += 1) {
      const previous = annotation.points[index - 1];
      const point = annotation.points[index];
      if (
        distToSegment(x, y, previous.x, previous.y, point.x, point.y) <=
        Math.max(slop, annotation.strokeWidth / 2 + 4)
      ) {
        return true;
      }
    }
    return (
      annotation.points.length === 1 &&
      Math.hypot(annotation.points[0].x - x, annotation.points[0].y - y) <= slop + 4
    );
  }
  if (annotation.type === "marker") {
    return Math.hypot(annotation.x - x, annotation.y - y) <= 16 + slop;
  }
  return pointInRect(x, y, annotationBounds(annotation), slop);
}

export function hitTest(annotations: Annotation[], x: number, y: number, slop: number) {
  for (let index = annotations.length - 1; index >= 0; index -= 1) {
    if (hitAnnotation(annotations[index], x, y, slop)) return annotations[index];
  }
  return null;
}

export function resizeAnnotation(origin: Annotation, handle: Handle, dx: number, dy: number): Annotation {
  if (origin.type === "line" || origin.type === "arrow") {
    if (handle === "start") return { ...origin, x: origin.x + dx, y: origin.y + dy };
    if (handle === "end") return { ...origin, x2: origin.x2 + dx, y2: origin.y2 + dy };
    return origin;
  }
  if (!isShape(origin)) return origin;
  const normalized = normalizeRect(origin.x, origin.y, origin.w, origin.h);
  let x1 = normalized.x;
  let y1 = normalized.y;
  let x2 = normalized.x + normalized.w;
  let y2 = normalized.y + normalized.h;
  if (handle === "nw" || handle === "w" || handle === "sw") x1 += dx;
  if (handle === "ne" || handle === "e" || handle === "se") x2 += dx;
  if (handle === "nw" || handle === "n" || handle === "ne") y1 += dy;
  if (handle === "sw" || handle === "s" || handle === "se") y2 += dy;
  return { ...origin, x: x1, y: y1, w: x2 - x1, h: y2 - y1 };
}

export function finalizeAnnotation(annotation: Annotation): Annotation {
  if (
    annotation.type === "rect" ||
    annotation.type === "rect-fill" ||
    annotation.type === "circle" ||
    annotation.type === "pixelate" ||
    annotation.type === "blur"
  ) {
    return { ...annotation, ...normalizeRect(annotation.x, annotation.y, annotation.w, annotation.h) };
  }
  return annotation;
}

export function cursorForHandle(handle: Handle) {
  switch (handle) {
    case "n":
    case "s":
      return "ns-resize";
    case "e":
    case "w":
      return "ew-resize";
    case "ne":
    case "sw":
      return "nesw-resize";
    case "nw":
    case "se":
      return "nwse-resize";
    default:
      return "crosshair";
  }
}

export function constrainLine(x1: number, y1: number, x2: number, y2: number, shift: boolean) {
  if (!shift) return { x2, y2 };
  const dx = x2 - x1;
  const dy = y2 - y1;
  const snapped = Math.round(Math.atan2(dy, dx) / (Math.PI / 4)) * (Math.PI / 4);
  const length = Math.hypot(dx, dy);
  return { x2: x1 + Math.cos(snapped) * length, y2: y1 + Math.sin(snapped) * length };
}

export function constrainBox(w: number, h: number, shift: boolean) {
  if (!shift) return { w, h };
  const size = Math.max(Math.abs(w), Math.abs(h));
  return { w: Math.sign(w || 1) * size, h: Math.sign(h || 1) * size };
}
