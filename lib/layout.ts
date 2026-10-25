import { CHROME_HEIGHT, type Doc, type LoadedImage, type Rect } from "./types";

export function fullImageRect(image: LoadedImage): Rect {
  return { x: 0, y: 0, w: image.width, h: image.height };
}

export function activeCrop(doc: Doc): Rect | null {
  if (!doc.image) return null;
  return doc.crop ?? fullImageRect(doc.image);
}

export type Composition = {
  image: Rect;
  window: Rect;
  compW: number;
  compH: number;
};

export function compositionOf(doc: Doc): Composition {
  const crop = activeCrop(doc);
  const width = crop?.w ?? 0;
  const height = crop?.h ?? 0;
  const pad = doc.style.padding;
  const chrome = doc.style.frame === "none" ? 0 : CHROME_HEIGHT;
  return {
    image: { x: pad, y: pad + chrome, w: width, h: height },
    window: { x: pad, y: pad, w: width, h: height + chrome },
    compW: Math.max(1, width + pad * 2),
    compH: Math.max(1, height + chrome + pad * 2),
  };
}

export function displayName(filename: string) {
  return filename.replace(/\.[^.]+$/, "") || filename;
}
