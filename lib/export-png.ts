import { desktopApi } from "./desktop";
import { compositionOf } from "./layout";
import { renderComposition } from "./render";
import type { Doc } from "./types";

export async function compositionBlob(doc: Doc, fontFamily: string, scale = 1) {
  if (!doc.image) throw new Error("Import a screenshot before exporting.");
  const { compW, compH } = compositionOf(doc);
  const canvas = document.createElement("canvas");
  canvas.width = Math.max(1, Math.round(compW * scale));
  canvas.height = Math.max(1, Math.round(compH * scale));
  const ctx = canvas.getContext("2d");
  if (!ctx) throw new Error("Couldn't start the export.");
  ctx.setTransform(scale, 0, 0, scale, 0, 0);
  renderComposition(ctx, doc, { fontFamily, interactive: false });
  const blob = await new Promise<Blob | null>((resolve) => canvas.toBlob(resolve, "image/png"));
  if (!blob) throw new Error("Couldn't create the PNG.");
  return blob;
}

export async function exportCompositionPng(doc: Doc, fontFamily: string, scale = 1) {
  const sourceName = doc.image?.name ?? "screenshot";
  const blob = await compositionBlob(doc, fontFamily, scale);

  const base =
    sourceName
      .replace(/\.[^.]+$/, "")
      .replace(/[^\w.-]+/g, "-")
      .replace(/-+/g, "-")
      .replace(/^-|-$/g, "") || "screenshot";
  const filename = `shotli-${base}.png`;
  const desktop = desktopApi();
  if (desktop) {
    const bytes = await blob.arrayBuffer();
    await desktop.savePng(bytes, filename);
    return;
  }
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = filename;
  document.body.appendChild(link);
  link.click();
  link.remove();
  URL.revokeObjectURL(url);
}

export async function copyCompositionPng(doc: Doc, fontFamily: string) {
  const blob = await compositionBlob(doc, fontFamily, 1);
  if (!navigator.clipboard || typeof ClipboardItem === "undefined") {
    throw new Error("This browser can't copy images to the clipboard.");
  }
  await navigator.clipboard.write([new ClipboardItem({ "image/png": blob })]);
}

export function fontFamilyFromDocument() {
  if (typeof document === "undefined") return "Geist, ui-sans-serif, sans-serif";
  return getComputedStyle(document.body).fontFamily || "Geist, ui-sans-serif, sans-serif";
}
