"use client";

import { useEffect, useRef, useState, type ReactNode } from "react";
import { compositionOf } from "@/lib/layout";
import { CANVASES, CARD_STYLES, COLORS, FONT_SIZES, GRADIENTS, INK_COLORS, LAYOUTS, PRESETS, SCENES, STROKE_WIDTHS, backgroundCss, stylesMatch } from "@/lib/presets";
import { renderComposition } from "@/lib/render";
import type { Annotation, Background, Brush, Doc, Style, Tool } from "@/lib/types";
import type { RecentShot } from "./library-home";

export function LeftRail({
  doc,
  recents,
  media,
  libraryOpen,
  fileDrag,
  className = "",
  onMedia,
  onStyleLive,
  onStyleCommit,
  onPreset,
  onGestureStart,
  onGestureEnd,
  onOpen,
  onOpenRecent,
  onFile,
  onSample,
  onCapture,
  onLibrary,
  tool,
  brush,
  onBrush,
  onPatchSelected,
  onDeleteSelected,
  onRemoveRedactions,
  onResetCrop,
}: {
  doc: Doc;
  recents: RecentShot[];
  media: "Screenshot" | "Image" | "Video";
  libraryOpen: boolean;
  fileDrag: boolean;
  className?: string;
  onMedia: (media: "Screenshot" | "Image" | "Video") => void;
  onStyleLive: (patch: Partial<Style>) => void;
  onStyleCommit: (patch: Partial<Style>) => void;
  onPreset: (style: Style) => void;
  onGestureStart: () => void;
  onGestureEnd: () => void;
  onOpen: () => void;
  onOpenRecent: (shot: RecentShot) => void;
  onFile: (file: File) => void;
  onSample: () => void;
  onCapture: () => void;
  onLibrary: () => void;
  tool: Tool;
  brush: Brush;
  onBrush: (patch: Partial<Brush>) => void;
  onPatchSelected: (patch: Partial<Annotation>) => void;
  onDeleteSelected: () => void;
  onRemoveRedactions: () => void;
  onResetCrop: () => void;
}) {
  const [more, setMore] = useState(true);
  const [borderOpen, setBorderOpen] = useState(true);
  const [backgroundOpen, setBackgroundOpen] = useState(true);
  const [canvasOpen, setCanvasOpen] = useState(false);
  const [presetCursor, setPresetCursor] = useState(0);
  const matched = PRESETS.findIndex((preset) => stylesMatch(preset.style, doc.style));
  const cursor = matched >= 0 ? matched : presetCursor;
  const frame = compositionOf(doc);
  const customCanvas = doc.style.canvasWidth > 0 && doc.style.canvasHeight > 0;
  const tab = doc.style.frame === "none" ? "mockup" : "frame";
  const styles = more ? CARD_STYLES : CARD_STYLES.slice(0, 5);

  useEffect(() => {
    if (matched >= 0) setPresetCursor(matched);
  }, [matched]);

  function cycle(step: number) {
    const nextIndex = (cursor + step + PRESETS.length) % PRESETS.length;
    setPresetCursor(nextIndex);
    onPreset(structuredClone(PRESETS[nextIndex].style));
  }

  return (
    <aside className={`flex h-full w-[280px] shrink-0 flex-col border-r border-black/8 bg-white ${className}`}>
      <div className="flex gap-1 p-3 pb-2">
        {(["mockup", "frame"] as const).map((item) => (
          <button
            key={item}
            type="button"
            aria-pressed={tab === item}
            className={`h-8 flex-1 rounded-lg text-[13px] capitalize ${tab === item ? "bg-ink text-white" : "bg-black/5 text-ink"}`}
            onClick={() => {
              if (item === "mockup") onStyleCommit({ frame: "none" });
              if (item === "frame") onStyleCommit({ frame: doc.style.frame === "none" ? "browser" : doc.style.frame });
            }}
          >
            {item}
          </button>
        ))}
      </div>
      <div className="min-h-0 flex-1 overflow-y-auto px-3 pb-4">
        {tab === "frame" ? (
          <div className="mb-3 grid grid-cols-2 gap-1">
            {(["browser", "desktop"] as const).map((frameStyle) => (
              <button
                key={frameStyle}
                type="button"
                aria-pressed={doc.style.frame === frameStyle}
                className={`h-8 rounded-lg text-[12px] capitalize ${doc.style.frame === frameStyle ? "bg-black/10 font-medium" : "text-muted"}`}
                onClick={() => onStyleCommit({ frame: frameStyle })}
              >
                {frameStyle === "desktop" ? "Window" : "Browser"}
              </button>
            ))}
          </div>
        ) : null}
        <label className="mb-3 block">
          <span className="sr-only">Input type</span>
          <select
            aria-label="Input type"
            value={media}
            onChange={(event) => onMedia(event.target.value as "Screenshot" | "Image" | "Video")}
            className="h-9 w-full rounded-lg border border-black/10 bg-white px-2 text-[13px]"
          >
            <option>Screenshot</option>
            <option>Image</option>
            <option>Video</option>
          </select>
        </label>

        <div className="mb-4 flex items-center gap-2">
          <button type="button" className="h-8 w-8 rounded-full bg-black/5 text-lg leading-none" aria-label="Previous preset" onClick={() => cycle(-1)}>
            ‹
          </button>
          <div className="min-w-0 flex-1 text-center">
            <div className="text-[10px] font-semibold tracking-[0.08em] text-muted uppercase">Magic preset</div>
            <div className="truncate text-[13px] font-medium">{presetLabel(doc.style, matched)}</div>
          </div>
          <button type="button" className="h-8 w-8 rounded-full bg-black/5 text-lg leading-none" aria-label="Next preset" onClick={() => cycle(1)}>
            ›
          </button>
        </div>

        <div className="text-[10px] font-semibold tracking-[0.08em] text-muted uppercase">Media</div>
        <button
          type="button"
          onClick={onOpen}
          onDragOver={(event) => {
            if (Array.from(event.dataTransfer.types).includes("Files")) event.preventDefault();
          }}
          onDrop={(event) => {
            event.preventDefault();
            event.stopPropagation();
            const file = event.dataTransfer.files?.[0];
            if (file) onFile(file);
          }}
          className={`mt-2 flex w-full flex-col items-center justify-center gap-1 rounded-xl border border-dashed px-3 py-4 text-center ${fileDrag ? "border-accent bg-accent/5" : "border-black/15 bg-black/[0.02]"}`}
        >
          <span className="flex h-8 w-8 items-center justify-center rounded-full bg-black/5 text-lg">+</span>
          <span className="text-[12px] text-muted">Drop media or click to choose</span>
          {doc.image ? <span className="max-w-full truncate text-[12px] text-ink">{doc.image.name}</span> : null}
        </button>
        <div className="mt-2 flex gap-3 px-1">
          <button type="button" className="text-[12px] text-muted hover:text-ink" onClick={onSample}>
            Try a sample
          </button>
          <button type="button" className="text-[12px] text-muted hover:text-ink" onClick={onCapture}>
            Capture screen
          </button>
        </div>
        {recents.length > 0 ? (
          <div className="mt-2 flex flex-col gap-1">
            {recents.slice(0, 4).map((shot) => (
              <button key={shot.id} type="button" className="truncate rounded-md px-2 py-1 text-left text-[12px] hover:bg-black/5" onClick={() => onOpenRecent(shot)}>
                {shot.name}
              </button>
            ))}
          </div>
        ) : null}

        <div className="mt-5 text-[10px] font-semibold tracking-[0.08em] text-muted uppercase">Style</div>
        <div className="mt-2 grid grid-cols-3 gap-2">
          {styles.map((item) => {
            const active = doc.style.card === item.id;
            const preview: Style = {
              ...doc.style,
              card: item.id,
              radius: item.radius,
              shadow: item.shadow,
              borderWidth: item.borderWidth,
              tilt: 0,
              padding: 84,
              canvas: "16:9",
              canvasWidth: 0,
              canvasHeight: 0,
              background: swatchBackground(doc.style.background),
            };
            return (
              <button
                key={item.id}
                type="button"
                aria-pressed={active}
                aria-label={item.name}
                className={`overflow-hidden rounded-xl border-2 bg-white p-1 text-left ${active ? "border-accent" : "border-transparent"}`}
                onClick={() => onStyleCommit({ card: item.id, radius: item.radius, shadow: item.shadow, borderWidth: item.borderWidth })}
              >
                <MiniStage doc={doc} style={preview} className="h-[52px]" />
                <span className="mt-1 block truncate px-0.5 text-[10px] text-ink">{item.name}</span>
              </button>
            );
          })}
          <button
            type="button"
            className="flex h-[78px] items-center justify-center rounded-xl border border-black/10 text-[18px] text-muted"
            aria-label={more ? "Show fewer styles" : "Show all styles"}
            onClick={() => setMore((open) => !open)}
          >
            …
          </button>
        </div>

        <Section title="Background" open={backgroundOpen} onToggle={() => setBackgroundOpen((open) => !open)}>
          <div className="grid grid-cols-8 gap-1.5">
            {COLORS.map((color) => (
              <button
                key={color}
                type="button"
                aria-label={color === "transparent" ? "Transparent background" : color}
                aria-pressed={sameBackground(doc.style.background, { kind: "color", color })}
                className={`h-6 rounded-md border ${sameBackground(doc.style.background, { kind: "color", color }) ? "border-accent" : "border-black/10"}`}
                style={{ background: backgroundCss({ kind: "color", color }) }}
                onClick={() => onStyleCommit({ background: { kind: "color", color } })}
              />
            ))}
          </div>
          <div className="mt-2 grid grid-cols-4 gap-1.5">
            {GRADIENTS.slice(0, 8).map((gradient) => {
              const background: Background = { kind: "gradient", from: gradient.from, to: gradient.to, angle: gradient.angle };
              return (
                <button
                  key={gradient.name}
                  type="button"
                  aria-label={gradient.name}
                  title={gradient.name}
                  aria-pressed={sameBackground(doc.style.background, background)}
                  className={`h-8 rounded-md border ${sameBackground(doc.style.background, background) ? "border-accent" : "border-black/10"}`}
                  style={{ background: backgroundCss(background) }}
                  onClick={() => onStyleCommit({ background })}
                />
              );
            })}
          </div>
          <div className="mt-2 grid grid-cols-3 gap-1.5">
            {SCENES.map((scene) => {
              const background: Background = { kind: "wallpaper", id: scene.id };
              return (
                <button
                  key={scene.id}
                  type="button"
                  aria-pressed={sameBackground(doc.style.background, background)}
                  className={`h-10 rounded-md border text-[10px] font-medium text-white ${sameBackground(doc.style.background, background) ? "border-accent" : "border-transparent"}`}
                  style={{ background: backgroundCss(background) }}
                  onClick={() => onStyleCommit({ background })}
                >
                  {scene.name}
                </button>
              );
            })}
          </div>
        </Section>

        <Section title="Border" open={borderOpen} onToggle={() => setBorderOpen((open) => !open)}>
          <Field label="Padding" value={doc.style.padding} min={0} max={200} onStart={onGestureStart} onEnd={onGestureEnd} onChange={(padding) => onStyleLive({ padding })} />
          <Field label="Radius" value={doc.style.radius} min={0} max={80} onStart={onGestureStart} onEnd={onGestureEnd} onChange={(radius) => onStyleLive({ radius })} />
          <Field label="Shadow" value={doc.style.shadow} min={0} max={100} onStart={onGestureStart} onEnd={onGestureEnd} onChange={(shadow) => onStyleLive({ shadow })} />
          <Field label="Stroke" value={doc.style.borderWidth} min={0} max={16} onStart={onGestureStart} onEnd={onGestureEnd} onChange={(borderWidth) => onStyleLive({ borderWidth })} />
        </Section>

        <Section title="Canvas" open={canvasOpen} onToggle={() => setCanvasOpen((open) => !open)}>
          <div className="grid grid-cols-5 gap-1">
            {CANVASES.map((item) => {
              const active = !customCanvas && doc.style.canvas === item.id;
              return (
                <button
                  key={item.id}
                  type="button"
                  aria-pressed={active}
                  className={`h-7 rounded-md text-[11px] ${active ? "bg-accent font-semibold text-white" : "bg-black/5 text-ink"}`}
                  onClick={() => onStyleCommit({ canvas: item.id, canvasWidth: 0, canvasHeight: 0 })}
                >
                  {item.label}
                </button>
              );
            })}
          </div>
          <div className="mt-2 grid grid-cols-2 gap-2">
            <SizeInput
              label="Width"
              value={Math.round(frame.compW)}
              onCommit={(width) => onStyleCommit({ canvasWidth: width, canvasHeight: Math.round(frame.compH) })}
            />
            <SizeInput
              label="Height"
              value={Math.round(frame.compH)}
              onCommit={(height) => onStyleCommit({ canvasWidth: Math.round(frame.compW), canvasHeight: height })}
            />
          </div>
        </Section>

        <Markup
          doc={doc}
          tool={tool}
          brush={brush}
          onBrush={onBrush}
          onPatchSelected={onPatchSelected}
          onDeleteSelected={onDeleteSelected}
          onRemoveRedactions={onRemoveRedactions}
          onResetCrop={onResetCrop}
          onGestureStart={onGestureStart}
          onGestureEnd={onGestureEnd}
        />

        <button type="button" className="mt-6 text-[12px] text-muted hover:text-ink" onClick={onLibrary}>
          {libraryOpen ? "Back to canvas" : "Library"}
        </button>
      </div>
    </aside>
  );
}

export function RightRail({
  doc,
  zoom,
  tiltMode,
  output,
  scale,
  className = "",
  onApplyLayout,
  onZoom,
  onFit,
  onTilt,
  onOutput,
  onScale,
  onExport,
  onCopy,
  onUndo,
  onRedo,
}: {
  doc: Doc;
  zoom: { percent: number; mode: "fit" | "manual" };
  tiltMode: "tilt" | "precision";
  output: "image" | "video" | "frames";
  scale: 1 | 2;
  className?: string;
  onApplyLayout: (style: Style) => void;
  onZoom: (percent: number) => void;
  onFit: () => void;
  onTilt: (mode: "tilt" | "precision") => void;
  onOutput: (mode: "image" | "video" | "frames") => void;
  onScale: (scale: 1 | 2) => void;
  onExport: () => void;
  onCopy: () => void;
  onUndo: () => void;
  onRedo: () => void;
}) {
  const [menu, setMenu] = useState(false);
  const [zoomDraft, setZoomDraft] = useState<string | null>(null);
  return (
    <aside className={`flex h-full w-[300px] shrink-0 flex-col border-l border-black/8 bg-white ${className}`}>
      <div className="flex items-center gap-1.5 p-3">
        <button type="button" className="h-9 flex-1 rounded-lg bg-ink text-[13px] font-medium text-white" onClick={onExport}>
          {scale}x · PNG
        </button>
        <button type="button" className="flex h-9 w-9 items-center justify-center rounded-lg border border-black/10" aria-label="Copy image" onClick={onCopy}>
          <CopyIcon />
        </button>
        <div className="relative">
          <button type="button" className="flex h-9 w-9 items-center justify-center rounded-lg border border-black/10" aria-label="Export settings" aria-expanded={menu} onClick={() => setMenu((open) => !open)}>
            <GearIcon />
          </button>
          {menu ? (
            <div className="absolute top-10 right-0 z-20 w-40 rounded-xl border border-black/10 bg-white p-1 text-[13px] shadow-lg">
              <button type="button" className="block w-full rounded-lg px-2 py-1.5 text-left hover:bg-black/5" onClick={() => { onScale(scale === 1 ? 2 : 1); setMenu(false); }}>
                Export {scale === 1 ? "2x" : "1x"}
              </button>
              <button type="button" className="block w-full rounded-lg px-2 py-1.5 text-left hover:bg-black/5" onClick={() => { onUndo(); setMenu(false); }}>
                Undo
              </button>
              <button type="button" className="block w-full rounded-lg px-2 py-1.5 text-left hover:bg-black/5" onClick={() => { onRedo(); setMenu(false); }}>
                Redo
              </button>
            </div>
          ) : null}
        </div>
      </div>
      <div className="mx-3 grid grid-cols-3 gap-1 rounded-xl bg-black/5 p-1" role="group" aria-label="Output mode">
        {(
          [
            ["image", "Image", <ImageModeIcon key="image" />],
            ["video", "Paused video", <VideoModeIcon key="video" />],
            ["frames", "Frames", <FramesModeIcon key="frames" />],
          ] as const
        ).map(([id, label, icon]) => (
          <button
            key={id}
            type="button"
            aria-label={label}
            aria-pressed={output === id}
            title={label}
            className={`flex h-9 items-center justify-center rounded-lg ${output === id ? "bg-white text-ink shadow-sm" : "text-muted"}`}
            onClick={() => onOutput(id)}
          >
            {icon}
          </button>
        ))}
      </div>
      <div className="mt-4 min-h-0 flex-1 overflow-y-auto px-3 pb-3">
        <div className="mb-2 text-[10px] font-semibold tracking-[0.08em] text-muted uppercase">
          {output === "frames" ? "Frames" : "Layout presets"}
        </div>
        <div className="flex flex-col gap-3">
          {LAYOUTS.map((layout) => {
            const active = stylesMatch(layout.style, doc.style);
            return (
              <button
                key={layout.id}
                type="button"
                aria-pressed={active}
                className={`overflow-hidden rounded-2xl border-2 p-1.5 text-left ${active ? "border-accent bg-white" : "border-transparent bg-black/[0.03]"}`}
                onClick={() => onApplyLayout(structuredClone(layout.style))}
              >
                <MiniStage doc={doc} style={layout.style} tilt={layout.style.tilt} className="h-[132px]" />
                <span className="mt-1.5 block px-1 text-[12px] text-ink">{layout.name}</span>
              </button>
            );
          })}
        </div>
      </div>
      <div className="border-t border-black/8 p-3">
        <div className="mb-1 flex items-center justify-between text-[12px]">
          <span className="font-medium">Zoom</span>
          <span className="flex items-center gap-1.5">
            <input
              aria-label="Zoom percent"
              type="number"
              min={8}
              max={600}
              value={zoomDraft ?? String(zoom.percent)}
              onFocus={() => setZoomDraft(String(zoom.percent))}
              onChange={(event) => setZoomDraft(event.target.value)}
              onBlur={() => {
                commitZoom(zoomDraft, zoom.percent, onZoom);
                setZoomDraft(null);
              }}
              onKeyDown={(event) => {
                if (event.key === "Enter") {
                  event.preventDefault();
                  commitZoom(zoomDraft, zoom.percent, onZoom);
                  setZoomDraft(null);
                }
              }}
              className="h-7 w-14 rounded-md border border-black/10 bg-white px-1.5 text-right text-[12px]"
            />
            <span className="text-muted">%</span>
            <button type="button" className={`h-7 rounded-md px-2 ${zoom.mode === "fit" ? "bg-accent text-white" : "bg-black/5 text-ink"}`} onClick={onFit}>
              Fit
            </button>
          </span>
        </div>
        <input
          aria-label="Zoom"
          type="range"
          min={20}
          max={200}
          value={Math.min(200, Math.max(20, zoom.percent || 100))}
          onChange={(event) => onZoom(Number(event.target.value))}
          className="w-full"
        />
        <div className="mt-2 grid grid-cols-2 gap-1 rounded-full bg-black/5 p-1" role="group" aria-label="View mode">
          {(["tilt", "precision"] as const).map((mode) => (
            <button
              key={mode}
              type="button"
              aria-pressed={tiltMode === mode}
              className={`h-8 rounded-full text-[12px] capitalize ${tiltMode === mode ? "bg-white shadow-sm" : "text-muted"}`}
              onClick={() => onTilt(mode)}
            >
              {mode}
            </button>
          ))}
        </div>
      </div>
    </aside>
  );
}

export function MiniStage({ doc, style, tilt = 0, className = "h-12" }: { doc: Doc; style: Style; tilt?: number; className?: string }) {
  const ref = useRef<HTMLCanvasElement>(null);
  const styleKey = JSON.stringify(style);
  const image = doc.image;
  const crop = doc.crop;
  const annotations = doc.annotations;
  useEffect(() => {
    const canvas = ref.current;
    if (!canvas) return;
    const preview: Doc = { image, crop, style: JSON.parse(styleKey) as Style, annotations, selectedId: null };
    const frame = compositionOf(preview);
    const longest = Math.max(frame.compW, frame.compH, 1);
    const factor = 360 / longest;
    canvas.width = Math.max(1, Math.round(frame.compW * factor));
    canvas.height = Math.max(1, Math.round(frame.compH * factor));
    const ctx = canvas.getContext("2d");
    if (!ctx) return;
    ctx.setTransform(factor, 0, 0, factor, 0, 0);
    renderComposition(ctx, preview, { interactive: false });
  }, [annotations, crop, image, styleKey]);
  return (
    <div className={`flex items-center justify-center overflow-hidden rounded-lg bg-[#ececec] ${className}`} style={{ perspective: 800 }}>
      <canvas
        ref={ref}
        className="max-h-full max-w-full"
        style={{
          transform: tilt ? `perspective(520px) rotateX(${Math.min(22, 7 + tilt * 0.55)}deg) rotateY(${Math.min(14, 4 + tilt * 0.28)}deg)` : undefined,
          transformOrigin: "center center",
        }}
      />
    </div>
  );
}

function Markup({
  doc,
  tool,
  brush,
  onBrush,
  onPatchSelected,
  onDeleteSelected,
  onRemoveRedactions,
  onResetCrop,
  onGestureStart,
  onGestureEnd,
}: {
  doc: Doc;
  tool: Tool;
  brush: Brush;
  onBrush: (patch: Partial<Brush>) => void;
  onPatchSelected: (patch: Partial<Annotation>) => void;
  onDeleteSelected: () => void;
  onRemoveRedactions: () => void;
  onResetCrop: () => void;
  onGestureStart: () => void;
  onGestureEnd: () => void;
}) {
  const selected = doc.annotations.find((annotation) => annotation.id === doc.selectedId) ?? null;
  const redactions = doc.annotations.some((annotation) => annotation.type === "pixelate" || annotation.type === "blur");
  const show = Boolean(doc.image) && (selected != null || tool !== "select" || Boolean(doc.crop) || redactions);
  if (!show) return null;
  const text = tool === "text" || selected?.type === "text";
  const color = selected?.color ?? brush.color;
  return (
    <section className="mt-5 border-t border-black/8 pt-3">
      <div className="text-[10px] font-semibold tracking-[0.08em] text-muted uppercase">Markup</div>
      <div className="mt-2 flex flex-wrap gap-1.5">
        {INK_COLORS.map((ink) => (
          <button
            key={ink}
            type="button"
            aria-label={ink}
            aria-pressed={color === ink}
            className={`h-6 w-6 rounded-full border ${color === ink ? "border-accent" : "border-black/10"}`}
            style={{ background: ink }}
            onClick={() => {
              onGestureStart();
              onBrush({ color: ink });
              if (selected) onPatchSelected({ color: ink });
              onGestureEnd();
            }}
          />
        ))}
      </div>
      <div className="mt-2 flex flex-wrap gap-1">
        {(text ? FONT_SIZES : STROKE_WIDTHS).map((value) => {
          const current = text ? (selected?.type === "text" ? selected.fontSize : brush.fontSize) : selected && "strokeWidth" in selected ? selected.strokeWidth : brush.strokeWidth;
          return (
            <button
              key={value}
              type="button"
              aria-pressed={current === value}
              className={`h-7 min-w-7 rounded-md px-2 text-[12px] ${current === value ? "bg-ink text-white" : "bg-black/5"}`}
              onClick={() => {
                onGestureStart();
                if (text) {
                  onBrush({ fontSize: value });
                  if (selected?.type === "text") onPatchSelected({ fontSize: value });
                } else {
                  onBrush({ strokeWidth: value });
                  if (selected) onPatchSelected({ strokeWidth: value });
                }
                onGestureEnd();
              }}
            >
              {value}
            </button>
          );
        })}
      </div>
      <div className="mt-2 flex flex-wrap gap-2">
        {selected ? (
          <button type="button" className="text-[12px] text-muted hover:text-ink" onClick={onDeleteSelected}>
            Delete
          </button>
        ) : null}
        {redactions ? (
          <button type="button" className="text-[12px] text-muted hover:text-ink" onClick={onRemoveRedactions}>
            Clear redactions
          </button>
        ) : null}
        {doc.crop ? (
          <button type="button" className="text-[12px] text-muted hover:text-ink" onClick={onResetCrop}>
            Reset crop
          </button>
        ) : null}
      </div>
    </section>
  );
}

function Section({ title, open, onToggle, children }: { title: string; open: boolean; onToggle: () => void; children: ReactNode }) {
  return (
    <section className="mt-5 border-t border-black/8 pt-3">
      <button type="button" className="flex w-full items-center justify-between text-[10px] font-semibold tracking-[0.08em] text-muted uppercase" aria-expanded={open} onClick={onToggle}>
        {title}
        <span>{open ? "–" : "+"}</span>
      </button>
      {open ? <div className="mt-3 flex flex-col gap-3">{children}</div> : null}
    </section>
  );
}

function Field({
  label,
  value,
  min,
  max,
  onChange,
  onStart,
  onEnd,
}: {
  label: string;
  value: number;
  min: number;
  max: number;
  onChange: (value: number) => void;
  onStart: () => void;
  onEnd: () => void;
}) {
  return (
    <label className="block text-[12px] text-muted">
      <span className="mb-1 flex justify-between">
        {label}
        <span className="text-ink">{Math.round(value)}</span>
      </span>
      <input
        type="range"
        min={min}
        max={max}
        value={value}
        aria-label={label}
        onPointerDown={(event) => {
          event.currentTarget.setPointerCapture(event.pointerId);
          onStart();
        }}
        onPointerUp={onEnd}
        onLostPointerCapture={onEnd}
        onChange={(event) => onChange(Number(event.target.value))}
        className="w-full"
      />
    </label>
  );
}

function SizeInput({ label, value, onCommit }: { label: string; value: number; onCommit: (value: number) => void }) {
  return (
    <label className="flex h-8 items-center gap-1.5 rounded-lg border border-black/10 bg-white px-2 text-[12px] text-muted">
      {label === "Width" ? "W" : "H"}
      <input
        aria-label={`Canvas ${label.toLowerCase()}`}
        defaultValue={value}
        key={value}
        inputMode="numeric"
        className="w-full bg-transparent text-ink outline-none"
        onBlur={(event) => commitSize(event.currentTarget.value, value, onCommit)}
        onKeyDown={(event) => {
          if (event.key === "Enter") {
            event.preventDefault();
            commitSize(event.currentTarget.value, value, onCommit);
          }
        }}
      />
    </label>
  );
}

function commitSize(raw: string, fallback: number, onCommit: (value: number) => void) {
  const next = Math.round(Number(raw));
  if (!Number.isFinite(next) || next < 32 || next === fallback) return;
  onCommit(next);
}

function commitZoom(raw: string | null, fallback: number, onZoom: (percent: number) => void) {
  const next = Math.round(Number(raw));
  if (!Number.isFinite(next) || next < 8 || next > 600 || next === fallback) return;
  onZoom(next);
}

function presetLabel(style: Style, matched: number) {
  if (matched >= 0) return PRESETS[matched].name;
  return LAYOUTS.find((layout) => stylesMatch(layout.style, style))?.name ?? "Custom";
}

function swatchBackground(background: Background): Background {
  if (background.kind === "color" && luminance(background.color) > 0.82) {
    return { kind: "gradient", from: "#b7c5d8", to: "#f4ece4", angle: 145 };
  }
  return background;
}

function luminance(color: string) {
  const hex = color.trim();
  if (!hex.startsWith("#") || (hex.length !== 7 && hex.length !== 4)) return 1;
  const full = hex.length === 4 ? `#${hex[1]}${hex[1]}${hex[2]}${hex[2]}${hex[3]}${hex[3]}` : hex;
  const r = Number.parseInt(full.slice(1, 3), 16);
  const g = Number.parseInt(full.slice(3, 5), 16);
  const b = Number.parseInt(full.slice(5, 7), 16);
  return (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255;
}

function sameBackground(a: Background, b: Background) {
  return JSON.stringify(a) === JSON.stringify(b);
}

function CopyIcon() {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" aria-hidden="true">
      <rect x="8" y="8" width="11" height="11" rx="2" />
      <path d="M6 16H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1" />
    </svg>
  );
}

function GearIcon() {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" aria-hidden="true">
      <circle cx="12" cy="12" r="3" />
      <path d="M12 3.5v2.2M12 18.3v2.2M4.8 6.6l1.6 1.6M17.6 15.8l1.6 1.6M3.5 12h2.2M18.3 12h2.2M4.8 17.4l1.6-1.6M17.6 8.2l1.6-1.6" strokeLinecap="round" />
    </svg>
  );
}

function ImageModeIcon() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" aria-hidden="true">
      <rect x="4" y="5" width="16" height="14" rx="2" />
      <circle cx="9" cy="10" r="1.3" fill="currentColor" stroke="none" />
      <path d="M4.5 16.5 9 12l3 3 2.5-2 5 4.5" strokeLinejoin="round" />
    </svg>
  );
}

function VideoModeIcon() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" aria-hidden="true">
      <rect x="3.5" y="6" width="12" height="12" rx="2" />
      <path d="M15.5 10.2 20 8v8l-4.5-2.2z" strokeLinejoin="round" />
    </svg>
  );
}

function FramesModeIcon() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" aria-hidden="true">
      <rect x="3" y="6" width="9" height="12" rx="1.5" />
      <rect x="8" y="4" width="9" height="12" rx="1.5" />
      <rect x="13" y="7.5" width="8" height="11" rx="1.5" />
    </svg>
  );
}
