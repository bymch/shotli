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

export function contentSize(doc: Doc) {
  const crop = activeCrop(doc);
  const width = crop?.w ?? 0;
  const height = crop?.h ?? 0;
  const pad = doc.style.padding;
  const chrome = doc.style.frame === "none" ? 0 : CHROME_HEIGHT;
  return {
    width,
    height,
    pad,
    chrome,
    contentW: Math.max(1, width + pad * 2),
    contentH: Math.max(1, height + chrome + pad * 2),
  };
}

export function compositionOf(doc: Doc): Composition {
  const { width, height, pad, chrome, contentW, contentH } = contentSize(doc);
  let compW = contentW;
  let compH = contentH;
  if (doc.style.canvasWidth > 0 && doc.style.canvasHeight > 0) {
    compW = Math.max(contentW, doc.style.canvasWidth);
    compH = Math.max(contentH, doc.style.canvasHeight);
  } else {
    const ratio = canvasRatio(doc.style.canvas);
    if (ratio && compH > 0) {
      const current = compW / compH;
      if (current > ratio) compH = compW / ratio;
      else if (current < ratio) compW = compH * ratio;
    }
  }
  const extraX = Math.max(0, compW - contentW);
  const extraY = Math.max(0, compH - contentH);
  return {
    image: { x: pad + extraX / 2, y: pad + chrome + extraY / 2, w: width, h: height },
    window: { x: pad + extraX / 2, y: pad + extraY / 2, w: width, h: height + chrome },
    compW,
    compH,
  };
}

function canvasRatio(canvas: Doc["style"]["canvas"]) {
  if (canvas === "1:1") return 1;
  if (canvas === "4:3") return 4 / 3;
  if (canvas === "3:2") return 3 / 2;
  if (canvas === "16:9") return 16 / 9;
  return null;
}

export function displayName(filename: string) {
  return filename.replace(/\.[^.]+$/, "") || filename;
}
