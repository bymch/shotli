"use client";

import { useEffect, useRef, useState } from "react";
import { exportCompositionPng, fontFamilyFromDocument } from "@/lib/export-png";
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
import { LookRail, Sidebar } from "./sidebar";
import { Toolbar } from "./toolbar";
import { Workspace } from "./workspace";

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
  const [sidebarOpen, setSidebarOpen] = useState(true);
  const [notice, setNotice] = useState<string | null>(null);
  const [fileDrag, setFileDrag] = useState(false);
  const [historyState, setHistoryState] = useState({ undo: false, redo: false });
  const [imageKey, setImageKey] = useState(0);
  const [librarySource, setLibrarySource] = useState<LibrarySourceId>("recent");
  const [recents, setRecents] = useState<RecentShot[]>([]);
  const fileRef = useRef<HTMLInputElement>(null);
  const history = useRef<{ past: Snapshot[]; future: Snapshot[] }>({ past: [], future: [] });
  const gesture = useRef<Snapshot | null>(null);
  const dragDepth = useRef(0);
  const importRef = useRef<(file: File) => void>(() => {});

  function setDocument(next: Doc) {
    docRef.current = next;
    setDoc(next);
  }

  function syncHistory() {
    setHistoryState({
      undo: history.current.past.length > 0,
      redo: history.current.future.length > 0,
    });
  }

  function pushHistory(before: Snapshot) {
    history.current.past.push(before);
    if (history.current.past.length > 60) history.current.past.shift();
    history.current.future = [];
    syncHistory();
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
    syncHistory();
  }

  function redo() {
    const next = history.current.future.pop();
    if (!next) return;
    history.current.past.push(snapshot(docRef.current));
    setDocument(applySnapshot(docRef.current, next));
    syncHistory();
  }

  function replaceImage(image: LoadedImage, message: string | null) {
    docRef.current.image?.bitmap.close();
    history.current = { past: [], future: [] };
    gesture.current = null;
    setImageKey((key) => key + 1);
    syncHistory();
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

  function showLibrary() {
    docRef.current.image?.bitmap.close();
    history.current = { past: [], future: [] };
    gesture.current = null;
    setImageKey((key) => key + 1);
    syncHistory();
    setDocument({
      image: null,
      crop: null,
      style: docRef.current.style,
      annotations: [],
      selectedId: null,
    });
    setNotice(null);
    setLibrarySource("recent");
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
    } catch {
      setNotice("Couldn't create the sample screenshot.");
    }
  }

  async function exportPng() {
    if (!docRef.current.image) return;
    try {
      await exportCompositionPng(docRef.current, fontFamilyFromDocument());
    } catch (error) {
      setNotice(error instanceof Error ? error.message : "Export failed.");
    }
  }

  function updateStyle(patch: Partial<Style>) {
    setDocument({ ...docRef.current, style: { ...docRef.current.style, ...patch } });
  }

  function setBackground(background: Style["background"]) {
    beginGesture();
    updateStyle({ background });
    endGesture();
  }

  function applyPreset(style: Style) {
    const before = snapshot(docRef.current);
    const next = { ...docRef.current, style: structuredClone(style) };
    if (!pictureChanged(before, snapshot(next))) return;
    setDocument(next);
    pushHistory(before);
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
      {doc.image ? <LookRail doc={doc} onPreset={applyPreset} /> : null}
      <div className="flex min-w-0 flex-1 flex-col">
        <Toolbar
          canUndo={historyState.undo}
          canRedo={historyState.redo}
          canExport={Boolean(doc.image)}
          sidebarOpen={sidebarOpen}
          onFile={(file) => void importFile(file)}
          onCapture={() => void captureScreen()}
          onSample={() => void loadSample()}
          onUndo={undo}
          onRedo={redo}
          onExport={() => void exportPng()}
          onToggleSidebar={() => setSidebarOpen((open) => !open)}
          onLibrary={showLibrary}
          fileRef={fileRef}
        />
        {doc.image ? (
          <Workspace
            key={imageKey}
            doc={doc}
            tool={tool}
            brush={brush}
            notice={notice}
            fileDrag={fileDrag}
            onNotice={setNotice}
            onCommit={(next, before) => {
              setDocument(next);
              if (pictureChanged(before, snapshot(next))) pushHistory(before);
            }}
            onLive={setDocument}
            onTool={setTool}
          />
        ) : (
          <LibraryHome
            source={librarySource}
            recents={recents}
            fileDrag={fileDrag}
            onSource={setLibrarySource}
            onOpen={() => fileRef.current?.click()}
            onOpenRecent={(shot) => void importFile(shot.file)}
            onSample={() => void loadSample()}
          />
        )}
      </div>
      {sidebarOpen && doc.image ? (
        <button
          type="button"
          className="absolute top-12 right-0 bottom-0 left-0 z-10 bg-black/10 min-[960px]:hidden"
          aria-label="Close properties"
          onClick={() => setSidebarOpen(false)}
        />
      ) : null}
      {doc.image ? (
      <Sidebar
        open={sidebarOpen}
        doc={doc}
        tool={tool}
        brush={brush}
        onPreset={applyPreset}
        onStyleLive={updateStyle}
        onGestureStart={beginGesture}
        onGestureEnd={endGesture}
        onBackground={setBackground}
        onBrush={(patch) => setBrush((current) => ({ ...current, ...patch }))}
        onPatchSelected={patchSelected}
        onDeleteSelected={deleteSelected}
        onRemoveRedactions={removeRedactions}
        onResetCrop={resetCrop}
        onClose={() => setSidebarOpen(false)}
        onDone={showLibrary}
      />
      ) : null}
    </div>
  );
}

function isTyping(target: EventTarget | null) {
  return target instanceof HTMLElement && (target.tagName === "INPUT" || target.tagName === "TEXTAREA" || target.isContentEditable);
}

function hasFiles(data: DataTransfer | null) {
  return Boolean(data && Array.from(data.types).includes("Files"));
}
