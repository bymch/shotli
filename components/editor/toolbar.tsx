"use client";

import { useEffect, useRef, useState, useSyncExternalStore, type ReactNode, type RefObject } from "react";
import {
  IconCrop,
  IconDownload,
  IconImport,
  IconRedo,
  IconSidebar,
  IconUndo,
  ShotliMark,
} from "./icons";

export function Toolbar({
  toolIsCrop,
  canUndo,
  canRedo,
  canExport,
  sidebarOpen,
  onFile,
  onCapture,
  onSample,
  onCrop,
  onUndo,
  onRedo,
  onExport,
  onToggleSidebar,
  onLibrary,
  fileRef,
}: {
  toolIsCrop: boolean;
  canUndo: boolean;
  canRedo: boolean;
  canExport: boolean;
  sidebarOpen: boolean;
  onFile: (file: File) => void;
  onCapture: () => void;
  onSample: () => void;
  onCrop: () => void;
  onUndo: () => void;
  onRedo: () => void;
  onExport: () => void;
  onToggleSidebar: () => void;
  onLibrary: () => void;
  fileRef: RefObject<HTMLInputElement | null>;
}) {
  const macApp = useSyncExternalStore(
    () => () => {},
    () => window.shotli?.platform === "darwin",
    () => false,
  );

  return (
    <header
      className={`relative z-30 flex h-12 shrink-0 items-center gap-1 border-b border-line bg-panel px-2.5 ${macApp ? "pl-[88px]" : ""}`}
    >
      {canExport ? (
        <button
          type="button"
          className="mr-1 inline-flex h-8 items-center gap-1 rounded-md px-1.5 text-[13px] text-ink hover:bg-surface"
          onClick={onLibrary}
        >
          <span aria-hidden="true" className="text-[15px] leading-none">‹</span>
          Library
        </button>
      ) : null}
      <div className="flex min-w-0 items-center gap-2 pr-2">
        <ShotliMark />
        <div className="min-w-0 leading-tight">
          <div className="text-[13px] font-semibold tracking-tight text-ink">Shotli</div>
        </div>
      </div>

      <input
        ref={fileRef}
        type="file"
        accept="image/png,image/jpeg,image/webp,.png,.jpg,.jpeg,.webp"
        className="sr-only"
        onChange={(event) => {
          const file = event.target.files?.[0];
          event.target.value = "";
          if (file) onFile(file);
        }}
      />

      <CaptureMenu
        onCapture={onCapture}
        onImport={() => fileRef.current?.click()}
        onSample={onSample}
      />

      <Divider />

      <ToolButton label="Crop" title="Crop the screenshot" pressed={toolIsCrop} disabled={!canExport} onClick={onCrop}>
        <IconCrop />
        <span className="hidden sm:inline">Crop</span>
      </ToolButton>

      <Divider />

      <ToolButton label="Undo" title="Undo" disabled={!canUndo} onClick={onUndo}>
        <IconUndo />
      </ToolButton>
      <ToolButton label="Redo" title="Redo" disabled={!canRedo} onClick={onRedo}>
        <IconRedo />
      </ToolButton>

      <div className="flex-1" />

      <button
        type="button"
        className="inline-flex h-8 items-center gap-1.5 rounded-md bg-accent px-2.5 text-[12px] font-medium text-white hover:bg-[#2d6ae0] disabled:cursor-not-allowed disabled:opacity-40"
        disabled={!canExport}
        onClick={onExport}
      >
        <IconDownload />
        <span className="hidden sm:inline">Export PNG</span>
        <span className="sm:hidden">Export</span>
      </button>
      <ToolButton
        label={sidebarOpen ? "Hide properties" : "Show properties"}
        title={sidebarOpen ? "Hide properties" : "Show properties"}
        pressed={sidebarOpen}
        disabled={!canExport}
        onClick={onToggleSidebar}
      >
        <IconSidebar />
      </ToolButton>
    </header>
  );
}

function ToolButton({
  label,
  title,
  pressed,
  disabled,
  onClick,
  children,
}: {
  label: string;
  title: string;
  pressed?: boolean;
  disabled?: boolean;
  onClick: () => void;
  children: ReactNode;
}) {
  return (
    <button
      type="button"
      aria-label={label}
      aria-pressed={pressed}
      title={title}
      disabled={disabled}
      onClick={onClick}
      className={`inline-flex h-8 items-center gap-1.5 rounded-md px-2 text-[12px] text-ink hover:bg-surface disabled:cursor-not-allowed disabled:opacity-40 ${pressed ? "bg-selected" : ""}`}
    >
      {children}
    </button>
  );
}

function Divider() {
  return <span className="mx-1 h-4 w-px bg-line" aria-hidden="true" />;
}

function CaptureMenu({
  onCapture,
  onImport,
  onSample,
}: {
  onCapture: () => void;
  onImport: () => void;
  onSample: () => void;
}) {
  const [open, setOpen] = useState(false);
  const rootRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) return;
    function onPointerDown(event: PointerEvent) {
      if (!rootRef.current?.contains(event.target as Node)) setOpen(false);
    }
    function onKey(event: KeyboardEvent) {
      if (event.key === "Escape") setOpen(false);
    }
    window.addEventListener("pointerdown", onPointerDown);
    window.addEventListener("keydown", onKey);
    return () => {
      window.removeEventListener("pointerdown", onPointerDown);
      window.removeEventListener("keydown", onKey);
    };
  }, [open]);

  return (
    <div ref={rootRef} className="relative">
      <button
        type="button"
        aria-haspopup="menu"
        aria-expanded={open}
        className="inline-flex h-8 items-center gap-1.5 rounded-md px-2 text-[12px] font-medium text-ink hover:bg-surface"
        onClick={() => setOpen((current) => !current)}
      >
        <IconImport />
        <span>Capture</span>
      </button>
      {open ? (
        <div
          role="menu"
          className="absolute top-9 left-0 z-40 w-56 rounded-lg border border-black/10 bg-white py-1 text-left shadow-[0_12px_32px_rgba(0,0,0,0.12)]"
        >
          <MenuRow label="Capture screen" onClick={() => { setOpen(false); onCapture(); }} />
          <MenuRow label="Open a screenshot…" onClick={() => { setOpen(false); onImport(); }} />
          <div className="my-1 h-px bg-line" />
          <MenuRow label="Use a sample" onClick={() => { setOpen(false); onSample(); }} />
        </div>
      ) : null}
    </div>
  );
}

function MenuRow({ label, onClick }: { label: string; onClick: () => void }) {
  return (
    <button
      type="button"
      role="menuitem"
      className="block w-full px-3 py-1.5 text-left text-[13px] text-ink hover:bg-surface"
      onClick={onClick}
    >
      {label}
    </button>
  );
}
