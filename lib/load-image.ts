import type { LoadedImage } from "./types";

const MAX_BYTES = 25 * 1024 * 1024;
const MAX_EDGE = 4096;

const TYPES = new Set(["image/png", "image/jpeg", "image/webp"]);

function sniffType(file: File) {
  if (TYPES.has(file.type)) return file.type;
  const extension = file.name.split(".").pop()?.toLowerCase();
  if (extension === "png") return "image/png";
  if (extension === "jpg" || extension === "jpeg") return "image/jpeg";
  if (extension === "webp") return "image/webp";
  return "";
}

export async function loadImageFile(file: File): Promise<{ image: LoadedImage } | { error: string }> {
  if (file.size > MAX_BYTES) {
    return { error: "That image is over 25 MB. Choose a smaller file." };
  }
  const type = sniffType(file);
  if (!TYPES.has(type)) {
    return { error: "Use a PNG, JPEG, or WebP image." };
  }

  try {
    const source = await createImageBitmap(file, { imageOrientation: "from-image" });
    let bitmap = source;
    let scaled = false;
    const edge = Math.max(source.width, source.height);
    if (edge > MAX_EDGE) {
      const scale = MAX_EDGE / edge;
      const width = Math.max(1, Math.round(source.width * scale));
      const height = Math.max(1, Math.round(source.height * scale));
      const canvas = document.createElement("canvas");
      canvas.width = width;
      canvas.height = height;
      const context = canvas.getContext("2d");
      if (!context) {
        source.close();
        return { error: "Couldn't read that image." };
      }
      context.drawImage(source, 0, 0, width, height);
      source.close();
      bitmap = await createImageBitmap(canvas);
      scaled = true;
    }
    return {
      image: {
        bitmap,
        width: bitmap.width,
        height: bitmap.height,
        name: file.name || "screenshot.png",
        scaled,
      },
    };
  } catch {
    return { error: "Couldn't read that image." };
  }
}

export function fileFromClipboard(data: DataTransfer | null) {
  if (!data) return null;
  for (const item of data.items) {
    if (item.kind === "file" && item.type.startsWith("image/")) {
      const file = item.getAsFile();
      if (file) return file;
    }
  }
  const file = data.files?.[0];
  return file ?? null;
}
