import { compositionOf } from "./layout";
import { renderComposition } from "./render";
import type { Doc } from "./types";

export async function exportCompositionPng(doc: Doc, fontFamily: string) {
  if (!doc.image) throw new Error("Import a screenshot before exporting.");
  const { compW, compH } = compositionOf(doc);
  const canvas = document.createElement("canvas");
  canvas.width = Math.max(1, Math.round(compW));
  canvas.height = Math.max(1, Math.round(compH));
  const ctx = canvas.getContext("2d");
  if (!ctx) throw new Error("Couldn't start the export.");
  renderComposition(ctx, doc, { fontFamily, interactive: false });
  const blob = await new Promise<Blob | null>((resolve) => canvas.toBlob(resolve, "image/png"));
  if (!blob) throw new Error("Couldn't create the PNG.");

  const base =
    doc.image.name
      .replace(/\.[^.]+$/, "")
      .replace(/[^\w.-]+/g, "-")
      .replace(/-+/g, "-")
      .replace(/^-|-$/g, "") || "screenshot";
  const filename = `shotli-${base}.png`;
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = filename;
  document.body.appendChild(link);
  link.click();
  link.remove();
  URL.revokeObjectURL(url);
}

export function fontFamilyFromDocument() {
  if (typeof document === "undefined") return "Geist, ui-sans-serif, sans-serif";
  return getComputedStyle(document.body).fontFamily || "Geist, ui-sans-serif, sans-serif";
}
