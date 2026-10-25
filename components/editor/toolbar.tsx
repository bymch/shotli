"use client";

import { useSyncExternalStore, type ReactNode, type RefObject } from "react";
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
  onCrop,
  onUndo,
  onRedo,
  onExport,
  onToggleSidebar,
  fileRef,
}: {
  toolIsCrop: boolean;
  canUndo: boolean;
  canRedo: boolean;
  canExport: boolean;
  sidebarOpen: boolean;
  onFile: (file: File) => void;
  onCrop: () => void;
  onUndo: () => void;
  onRedo: () => void;
  onExport: () => void;
  onToggleSidebar: () => void;
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

      <ToolButton label="Import" title="Import a screenshot" onClick={() => fileRef.current?.click()}>
        <IconImport />
        <span className="hidden sm:inline">Import</span>
      </ToolButton>

      <Divider />

      <ToolButton label="Crop" title="Crop the screenshot" pressed={toolIsCrop} onClick={onCrop}>
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
