"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { copyCompositionPng, exportCompositionPng, fontFamilyFromDocument } from "@/lib/export-png";
import { fileFromClipboard, loadImageFile } from "@/lib/load-image";
import { DEFAULT_STYLE } from "@/lib/presets";
import { createSampleImage } from "@/lib/sample";
import {
  applySnapshot,
  pictureChanged,
  snapshot,
  type Annotation,
  type Brush,
  type Doc,
  type LoadedImage,
  type Snapshot,
  type Style,
  type Tool,
} from "@/lib/types";
import { LibraryHome, type LibrarySourceId, type RecentShot } from "./library-home";
import { LeftRail, RightRail } from "./studio";
import { Workspace, type ZoomCommand } from "./workspace";

const INITIAL_BRUSH: Brush = {
  color: "#E5484D",
  strokeWidth: 4,
  pixelSize: 14,
  blur: 12,
  fontSize: 24,
};

function initialDoc(): Doc {
  return {
    image: null,
    crop: null,
    style: structuredClone(DEFAULT_STYLE),
    annotations: [],
    selectedId: null,
  };
}

const TOOL_KEYS: Record<string, Tool> = {
  v: "select",
  r: "rect",
  f: "rect-fill",
  c: "circle",
  l: "line",
  a: "arrow",
  d: "draw",
  t: "text",
  n: "marker",
  p: "pixelate",
  b: "blur",
  k: "crop",
};

export function Editor() {
  const [doc, setDoc] = useState<Doc>(initialDoc);
  const docRef = useRef(doc);
  const [tool, setTool] = useState<Tool>("select");
  const [brush, setBrush] = useState<Brush>(INITIAL_BRUSH);
  const [notice, setNotice] = useState<string | null>(null);
  const [fileDrag, setFileDrag] = useState(false);
  const [imageKey, setImageKey] = useState(0);
  const [librarySource, setLibrarySource] = useState<LibrarySourceId>("recent");
  const [libraryOpen, setLibraryOpen] = useState(false);
  const [recents, setRecents] = useState<RecentShot[]>([]);
  const [zoom, setZoom] = useState<{ percent: number; mode: "fit" | "manual" }>({ percent: 100, mode: "fit" });
  const [zoomCommand, setZoomCommand] = useState<ZoomCommand | null>(null);
  const [tiltMode, setTiltMode] = useState<"tilt" | "precision">("precision");
  const [animateToken, setAnimateToken] = useState(0);
  const [output, setOutput] = useState<"image" | "video" | "frames">("image");
  const [exportScale, setExportScale] = useState<1 | 2>(1);
  const [mediaKind, setMediaKind] = useState<"Screenshot" | "Image" | "Video">("Screenshot");
  const [narrow, setNarrow] = useState(false);
  const [rail, setRail] = useState<null | "style" | "export">(null);
  const fileRef = useRef<HTMLInputElement>(null);
  const exportScaleRef = useRef<1 | 2>(1);
  const outputRef = useRef(output);
  const zoomSeq = useRef(0);
  const history = useRef<{ past: Snapshot[]; future: Snapshot[] }>({ past: [], future: [] });
  const gesture = useRef<Snapshot | null>(null);
  const dragDepth = useRef(0);
  const importRef = useRef<(file: File) => void>(() => {});

  function setDocument(next: Doc) {
    docRef.current = next;
    setDoc(next);
  }

  function pushHistory(before: Snapshot) {
    history.current.past.push(before);
    if (history.current.past.length > 60) history.current.past.shift();
    history.current.future = [];
  }

  function beginGesture() {
    if (!gesture.current) gesture.current = snapshot(docRef.current);
  }

  function endGesture() {
    const before = gesture.current;
    gesture.current = null;
    if (before && pictureChanged(before, snapshot(docRef.current))) pushHistory(before);
  }

  function undo() {
    const previous = history.current.past.pop();
    if (!previous) return;
    history.current.future.push(snapshot(docRef.current));
    setDocument(applySnapshot(docRef.current, previous));
  }

  function redo() {
    const next = history.current.future.pop();
    if (!next) return;
    history.current.past.push(snapshot(docRef.current));
    setDocument(applySnapshot(docRef.current, next));
  }

  function replaceImage(image: LoadedImage, message: string | null) {
    docRef.current.image?.bitmap.close();
    history.current = { past: [], future: [] };
    gesture.current = null;
    setImageKey((key) => key + 1);
    setDocument({
      image,
      crop: null,
      style: docRef.current.style,
      annotations: [],
      selectedId: null,
    });
    setNotice(message);
  }

  async function importFile(file: File) {
    const result = await loadImageFile(file);
    if ("error" in result) {
      setNotice(result.error);
      return;
    }
    replaceImage(
      result.image,
      result.image.scaled
        ? "Scaled to 4096px on the long edge so editing stays responsive. Export uses this size."
        : null,
    );
    setLibraryOpen(false);
    setRail(null);
    remember(file);
  }

  function remember(file: File) {
    if (file.name === "sample-screenshot.png") return;
    const previewUrl = URL.createObjectURL(file);
    setRecents((current) => {
      const duplicate = current.find((shot) => shot.name === file.name && shot.file.size === file.size && shot.file.lastModified === file.lastModified);
      if (duplicate) URL.revokeObjectURL(previewUrl);
      const kept = duplicate ? current.filter((shot) => shot.id !== duplicate.id) : current;
      const next = [
        {
          id: `${file.name}-${file.size}-${file.lastModified}-${Date.now()}`,
          name: file.name,
          file: duplicate?.file ?? file,
          previewUrl: duplicate?.previewUrl ?? previewUrl,
          added: Date.now(),
        },
        ...kept,
      ];
      return next.slice(0, 24);
    });
  }

  function toggleLibrary() {
    setLibraryOpen((open) => !open);
    setRail(null);
  }

  const reportZoom = useCallback((info: { percent: number; mode: "fit" | "manual" }) => {
    setZoom((current) => (current.percent === info.percent && current.mode === info.mode ? current : info));
  }, []);

  function commandZoom(kind: ZoomCommand["kind"], percent?: number) {
    zoomSeq.current += 1;
    setZoomCommand({ id: zoomSeq.current, kind, percent });
  }

  useEffect(() => {
    importRef.current = (file: File) => {
      void importFile(file);
    };
  });

  async function captureScreen() {
    try {
      const stream = await navigator.mediaDevices.getDisplayMedia({ video: true, audio: false });
      const video = document.createElement("video");
      video.srcObject = stream;
      video.muted = true;
      await video.play();
      await new Promise((resolve) => requestAnimationFrame(resolve));
      const canvas = document.createElement("canvas");
      canvas.width = video.videoWidth;
      canvas.height = video.videoHeight;
      const context = canvas.getContext("2d");
      if (!context || canvas.width < 2 || canvas.height < 2) {
        stream.getTracks().forEach((track) => track.stop());
        setNotice("Couldn't capture the screen.");
        return;
      }
      context.drawImage(video, 0, 0);
      stream.getTracks().forEach((track) => track.stop());
      const blob = await new Promise<Blob | null>((resolve) => canvas.toBlob(resolve, "image/png"));
      if (!blob) {
        setNotice("Couldn't capture the screen.");
        return;
      }
      await importFile(new File([blob], "Screenshot.png", { type: "image/png" }));
    } catch (error) {
      if (error instanceof DOMException && error.name === "NotAllowedError") return;
      setNotice("Couldn't capture the screen.");
    }
  }

  async function loadSample() {
    try {
      replaceImage(await createSampleImage(), null);
      setLibraryOpen(false);
      setRail(null);
    } catch {
      setNotice("Couldn't create the sample screenshot.");
    }
  }

  async function exportPng() {
    if (!docRef.current.image) {
      setNotice("Add an image before exporting.");
      return;
    }
    if (outputRef.current === "video") {
      setAnimateToken((token) => token + 1);
      setNotice("Playing the intro. The download is a PNG of this frame.");
    }
    try {
      await exportCompositionPng(docRef.current, fontFamilyFromDocument(), exportScaleRef.current);
    } catch (error) {
      setNotice(error instanceof Error ? error.message : "Export failed.");
    }
  }

  async function copyPng() {
    if (!docRef.current.image) {
      setNotice("Add an image before copying.");
      return;
    }
    try {
      await copyCompositionPng(docRef.current, fontFamilyFromDocument());
      setNotice("Copied the image.");
    } catch (error) {
      setNotice(error instanceof Error ? error.message : "Couldn't copy the image.");
    }
  }

  function updateStyle(patch: Partial<Style>) {
    setDocument({ ...docRef.current, style: { ...docRef.current.style, ...patch } });
  }

  function applyPreset(style: Style) {
    const before = snapshot(docRef.current);
    const next = { ...docRef.current, style: structuredClone(style) };
    if (!pictureChanged(before, snapshot(next))) return;
    setDocument(next);
    pushHistory(before);
  }

  function commitPatch(patch: Partial<Style>) {
    applyPreset({ ...docRef.current.style, ...patch });
  }

  function applyLayout(style: Style) {
    applyPreset(style);
    if (style.tilt !== 0) setTiltMode("tilt");
  }

  function patchSelected(patch: Partial<Annotation>) {
    const id = docRef.current.selectedId;
    if (!id) return;
    setDocument({
      ...docRef.current,
      annotations: docRef.current.annotations.map((annotation) =>
        annotation.id === id ? ({ ...annotation, ...patch } as Annotation) : annotation,
      ),
    });
  }

  function deleteSelected() {
    const id = docRef.current.selectedId;
    if (!id) return;
    const before = snapshot(docRef.current);
    setDocument({
      ...docRef.current,
      annotations: docRef.current.annotations.filter((annotation) => annotation.id !== id),
      selectedId: null,
    });
    pushHistory(before);
  }

  function removeRedactions() {
    const before = snapshot(docRef.current);
    const annotations = docRef.current.annotations.filter(
      (annotation) => annotation.type !== "pixelate" && annotation.type !== "blur",
    );
    if (annotations.length === docRef.current.annotations.length) return;
    const selected = annotations.find((annotation) => annotation.id === docRef.current.selectedId);
    setDocument({ ...docRef.current, annotations, selectedId: selected ? selected.id : null });
    pushHistory(before);
  }

  function resetCrop() {
    if (!docRef.current.crop) return;
    const before = snapshot(docRef.current);
    setDocument({ ...docRef.current, crop: null });
    pushHistory(before);
  }

  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      const meta = event.metaKey || event.ctrlKey;
      const key = event.key.toLowerCase();
      if (meta && key === "s") {
        event.preventDefault();
        if (window.shotli || isTyping(event.target)) return;
        void exportPng();
        return;
      }
      if (meta && key === "e") {
        event.preventDefault();
        if (!window.shotli) void exportPng();
        return;
      }
      if (meta && key === "o") {
        event.preventDefault();
        if (!window.shotli) fileRef.current?.click();
        return;
      }
      if (isTyping(event.target)) return;
      if (meta && key === "z" && event.shiftKey) {
        event.preventDefault();
        redo();
        return;
      }
      if (meta && key === "z") {
        event.preventDefault();
        undo();
        return;
      }
      if (meta && key === "y") {
        event.preventDefault();
        redo();
        return;
      }
      if (event.key === "Delete" || event.key === "Backspace") {
        event.preventDefault();
        deleteSelected();
        return;
      }
      if (!meta && !event.altKey && TOOL_KEYS[key]) setTool(TOOL_KEYS[key]);
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
    // Handlers read the latest document through refs.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    exportScaleRef.current = exportScale;
    outputRef.current = output;
  });

  useEffect(() => {
    const query = window.matchMedia("(max-width: 1040px)");
    const apply = () => {
      setNarrow(query.matches);
      if (!query.matches) setRail(null);
    };
    apply();
    query.addEventListener("change", apply);
    return () => query.removeEventListener("change", apply);
  }, []);

  useEffect(() => {
    const desktop = window.shotli;
    if (!desktop) return;
    const stopOpen = desktop.onOpenFiles((files) => {
      const opened = files[0];
      if (!opened) return;
      importRef.current(new File([opened.bytes], opened.name, { type: opened.type }));
    });
    const stopExport = desktop.onExport(() => {
      void exportPng();
    });
    return () => {
      stopOpen();
      stopExport();
    };
  }, []);

  useEffect(() => {
    const onPaste = (event: ClipboardEvent) => {
      if (isTyping(event.target)) return;
      const file = fileFromClipboard(event.clipboardData);
      if (!file) {
        setNotice("Clipboard doesn't contain an image.");
        return;
      }
      event.preventDefault();
      importRef.current(file);
    };
    window.addEventListener("paste", onPaste);
    return () => window.removeEventListener("paste", onPaste);
  }, []);

  return (
    <div
      className="relative flex h-dvh w-full overflow-hidden bg-workspace text-ink"
      onDragEnter={(event) => {
        if (!hasFiles(event.dataTransfer)) return;
        event.preventDefault();
        dragDepth.current += 1;
        setFileDrag(true);
      }}
      onDragOver={(event) => {
        if (hasFiles(event.dataTransfer)) event.preventDefault();
      }}
      onDragLeave={() => {
        dragDepth.current = Math.max(0, dragDepth.current - 1);
        if (dragDepth.current === 0) setFileDrag(false);
      }}
      onDrop={(event) => {
        event.preventDefault();
        dragDepth.current = 0;
        setFileDrag(false);
        const file = event.dataTransfer.files?.[0];
        if (file) void importFile(file);
      }}
    >
      {narrow && rail ? (
        <button type="button" className="absolute inset-0 z-30 bg-black/20" aria-label="Close panel" onClick={() => setRail(null)} />
      ) : null}
      <LeftRail
        className={narrow ? `absolute inset-y-0 left-0 z-40 shadow-2xl ${rail === "style" ? "" : "hidden"}` : ""}
        doc={doc}
        recents={recents}
        media={mediaKind}
        libraryOpen={libraryOpen}
        fileDrag={fileDrag}
        onMedia={setMediaKind}
        onStyleLive={updateStyle}
        onStyleCommit={commitPatch}
        onPreset={applyPreset}
        onGestureStart={beginGesture}
        onGestureEnd={endGesture}
        onOpen={() => fileRef.current?.click()}
        onOpenRecent={(shot) => void importFile(shot.file)}
        onFile={(file) => void importFile(file)}
        onSample={() => void loadSample()}
        onCapture={() => void captureScreen()}
        onLibrary={toggleLibrary}
        tool={tool}
        brush={brush}
        onBrush={(patch) => setBrush((current) => ({ ...current, ...patch }))}
        onPatchSelected={patchSelected}
        onDeleteSelected={deleteSelected}
        onRemoveRedactions={removeRedactions}
        onResetCrop={resetCrop}
      />
      <div className="relative flex min-w-0 flex-1 flex-col">
        {narrow ? (
          <div className="flex h-11 shrink-0 items-center justify-between border-b border-black/8 bg-white px-2">
            <button type="button" className="h-8 rounded-lg px-3 text-[13px] hover:bg-black/5" onClick={() => setRail("style")}>
              Style
            </button>
            <div className="text-[13px] font-semibold tracking-tight">Shotli</div>
            <button type="button" className="h-8 rounded-lg px-3 text-[13px] hover:bg-black/5" onClick={() => setRail("export")}>
              Export
            </button>
          </div>
        ) : null}
        {libraryOpen ? (
          <LibraryHome
            source={librarySource}
            recents={recents}
            fileDrag={fileDrag}
            onSource={setLibrarySource}
            onOpen={() => fileRef.current?.click()}
            onOpenRecent={(shot) => void importFile(shot.file)}
            onSample={() => void loadSample()}
          />
        ) : (
          <Workspace
            key={imageKey}
            doc={doc}
            tool={tool}
            brush={brush}
            notice={notice}
            fileDrag={fileDrag}
            zoomCommand={zoomCommand}
            tiltMode={tiltMode === "tilt"}
            animateToken={animateToken}
            onNotice={setNotice}
            onCommit={(next, before) => {
              setDocument(next);
              if (pictureChanged(before, snapshot(next))) pushHistory(before);
            }}
            onLive={setDocument}
            onTool={setTool}
            onZoom={reportZoom}
            onRequestFile={() => fileRef.current?.click()}
          />
        )}
        {libraryOpen ? null : (
          <button
            type="button"
            className="absolute bottom-5 left-1/2 z-20 inline-flex h-11 -translate-x-1/2 items-center gap-2 rounded-full bg-ink px-5 text-[14px] font-medium text-white shadow-[0_12px_30px_rgba(0,0,0,0.2)]"
            onClick={() => {
              setAnimateToken((token) => token + 1);
              if (output === "video") setNotice("Playing the intro on the canvas.");
            }}
          >
            <PlayIcon />
            Animate
          </button>
        )}
      </div>
      <RightRail
        className={narrow ? `absolute inset-y-0 right-0 z-40 shadow-2xl ${rail === "export" ? "" : "hidden"}` : ""}
        doc={doc}
        zoom={zoom}
        tiltMode={tiltMode}
        output={output}
        scale={exportScale}
        onApplyLayout={applyLayout}
        onZoom={(percent) => commandZoom("percent", percent)}
        onFit={() => commandZoom("fit")}
        onTilt={setTiltMode}
        onOutput={setOutput}
        onScale={setExportScale}
        onExport={() => void exportPng()}
        onCopy={() => void copyPng()}
        onUndo={undo}
        onRedo={redo}
      />
      <input
        ref={fileRef}
        type="file"
        accept={
          mediaKind === "Video"
            ? "video/mp4,video/webm,video/quicktime,.mp4,.webm,.mov"
            : "image/png,image/jpeg,image/webp,video/mp4,video/webm,.png,.jpg,.jpeg,.webp,.mp4,.webm"
        }
        className="sr-only"
        onChange={(event) => {
          const file = event.target.files?.[0];
          event.target.value = "";
          if (file) void importFile(file);
        }}
      />
    </div>
  );
}

function PlayIcon() {
  return (
    <svg width="14" height="14" viewBox="0 0 16 16" fill="currentColor" aria-hidden="true">
      <path d="M4.5 2.8c0-.7.8-1.2 1.4-.8l7.2 4.2c.6.3.6 1.2 0 1.6l-7.2 4.2c-.6.4-1.4 0-1.4-.8V2.8Z" />
    </svg>
  );
}

function isTyping(target: EventTarget | null) {
  return target instanceof HTMLElement && (target.tagName === "INPUT" || target.tagName === "TEXTAREA" || target.isContentEditable);
}

function hasFiles(data: DataTransfer | null) {
  return Boolean(data && Array.from(data.types).includes("Files"));
}
