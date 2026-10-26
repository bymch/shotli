export type Tool =
  | "select"
  | "crop"
  | "rect"
  | "rect-fill"
  | "circle"
  | "line"
  | "arrow"
  | "draw"
  | "text"
  | "marker"
  | "pixelate"
  | "blur";

export type FrameStyle = "none" | "browser" | "desktop";

export type CardStyle =
  | "default"
  | "glass-light"
  | "glass-dark"
  | "liquid"
  | "inset-light"
  | "inset-dark"
  | "outline"
  | "border";

export type CanvasRatio = "auto" | "1:1" | "4:3" | "3:2" | "16:9";

export type WallpaperId =
  | "dots"
  | "grid"
  | "diagonal"
  | "stripes"
  | "mesh"
  | "cross"
  | "dusk"
  | "night"
  | "harbour"
  | "hills"
  | "aurora"
  | "sorbet";

export type Background =
  | { kind: "color"; color: string }
  | { kind: "gradient"; from: string; to: string; angle: number; mid?: string }
  | { kind: "wallpaper"; id: WallpaperId };

export type Style = {
  padding: number;
  radius: number;
  shadow: number;
  frame: FrameStyle;
  canvas: CanvasRatio;
  canvasWidth: number;
  canvasHeight: number;
  card: CardStyle;
  tilt: number;
  borderWidth: number;
  background: Background;
};

export type Rect = { x: number; y: number; w: number; h: number };

export type Handle = "nw" | "n" | "ne" | "e" | "se" | "s" | "sw" | "w" | "start" | "end";

type Mark = { id: string; color: string; strokeWidth: number };

export type ShapeAnnotation = Mark & {
  type: "rect" | "rect-fill" | "circle" | "pixelate" | "blur";
  x: number;
  y: number;
  w: number;
  h: number;
  amount: number;
};

export type LineAnnotation = Mark & {
  type: "line" | "arrow";
  x: number;
  y: number;
  x2: number;
  y2: number;
};

export type DrawAnnotation = Mark & {
  type: "draw";
  points: { x: number; y: number }[];
};

export type TextAnnotation = Mark & {
  type: "text";
  x: number;
  y: number;
  text: string;
  fontSize: number;
};

export type MarkerAnnotation = Mark & {
  type: "marker";
  x: number;
  y: number;
  n: number;
};

export type Annotation =
  | ShapeAnnotation
  | LineAnnotation
  | DrawAnnotation
  | TextAnnotation
  | MarkerAnnotation;

export type LoadedImage = {
  bitmap: ImageBitmap;
  width: number;
  height: number;
  name: string;
  scaled: boolean;
};

export type Doc = {
  image: LoadedImage | null;
  crop: Rect | null;
  style: Style;
  annotations: Annotation[];
  selectedId: string | null;
};

export type Snapshot = {
  crop: Rect | null;
  style: Style;
  annotations: Annotation[];
  selectedId: string | null;
};

export type Brush = {
  color: string;
  strokeWidth: number;
  pixelSize: number;
  blur: number;
  fontSize: number;
};

export const CHROME_HEIGHT = 46;

export function snapshot(doc: Doc): Snapshot {
  return {
    crop: doc.crop ? { ...doc.crop } : null,
    style: structuredClone(doc.style),
    annotations: structuredClone(doc.annotations),
    selectedId: doc.selectedId,
  };
}

export function applySnapshot(doc: Doc, snap: Snapshot): Doc {
  return {
    ...doc,
    crop: snap.crop ? { ...snap.crop } : null,
    style: structuredClone(snap.style),
    annotations: structuredClone(snap.annotations),
    selectedId: snap.selectedId,
  };
}

export function sameSnapshot(a: Snapshot, b: Snapshot) {
  return JSON.stringify(a) === JSON.stringify(b);
}

export function pictureChanged(a: Snapshot, b: Snapshot) {
  return (
    JSON.stringify({ crop: a.crop, style: a.style, annotations: a.annotations }) !==
    JSON.stringify({ crop: b.crop, style: b.style, annotations: b.annotations })
  );
}
