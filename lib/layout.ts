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

const EMPTY_PICTURE = { w: 960, h: 600 };

export function cardInset(style: Doc["style"]) {
  if (style.card === "glass-light" || style.card === "glass-dark" || style.card === "liquid") return 22;
  if (style.card === "inset-light" || style.card === "inset-dark") return 18;
  if (style.card === "border") return Math.max(12, style.borderWidth);
  return 0;
}

export function contentSize(doc: Doc) {
  const crop = activeCrop(doc);
  const width = crop?.w ?? (doc.image ? 0 : EMPTY_PICTURE.w);
  const height = crop?.h ?? (doc.image ? 0 : EMPTY_PICTURE.h);
  const pad = doc.style.padding;
  const chrome = doc.style.frame === "none" ? 0 : CHROME_HEIGHT;
  const inset = cardInset(doc.style);
  return {
    width,
    height,
    pad,
    chrome,
    inset,
    contentW: Math.max(1, width + pad * 2 + inset * 2),
    contentH: Math.max(1, height + chrome + pad * 2 + inset * 2),
  };
}

export function compositionOf(doc: Doc): Composition {
  const { width, height, pad, chrome, inset, contentW, contentH } = contentSize(doc);
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
  const originX = pad + extraX / 2;
  const originY = pad + extraY / 2;
  return {
    image: { x: originX + inset, y: originY + chrome + inset, w: width, h: height },
    window: { x: originX, y: originY, w: width + inset * 2, h: height + chrome + inset * 2 },
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
