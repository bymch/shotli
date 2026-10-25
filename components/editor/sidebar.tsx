"use client";

import { backgroundCss, COLORS, FONT_SIZES, GRADIENTS, INK_COLORS, PRESETS, STROKE_WIDTHS, stylesMatch, WALLPAPERS } from "@/lib/presets";
import type { Annotation, Brush, Doc, FrameStyle, Style, Tool } from "@/lib/types";
import { Segmented, SliderField, Swatches } from "./ui";

export function Sidebar({
  open,
  doc,
  tool,
  brush,
  onPreset,
  onStyleLive,
  onGestureStart,
  onGestureEnd,
  onBackground,
  onBrush,
  onPatchSelected,
  onDeleteSelected,
  onRemoveRedactions,
  onResetCrop,
  onClose,
  onDone,
}: {
  open: boolean;
  doc: Doc;
  tool: Tool;
  brush: Brush;
  onPreset: (style: Style) => void;
  onStyleLive: (patch: Partial<Style>) => void;
  onGestureStart: () => void;
  onGestureEnd: () => void;
  onBackground: (background: Style["background"]) => void;
  onBrush: (patch: Partial<Brush>) => void;
  onPatchSelected: (patch: Partial<Annotation>) => void;
  onDeleteSelected: () => void;
  onRemoveRedactions: () => void;
  onResetCrop: () => void;
  onClose: () => void;
  onDone: () => void;
}) {
  if (!open) return null;
  const selected = doc.annotations.find((annotation) => annotation.id === doc.selectedId) ?? null;
  const redactionCount = doc.annotations.filter(
    (annotation) => annotation.type === "pixelate" || annotation.type === "blur",
  ).length;
  const showTextSize = tool === "text" || selected?.type === "text";
  const showMark = selected != null || (tool !== "select" && tool !== "crop");

  return (
    <aside className="absolute top-12 right-0 bottom-0 z-20 flex w-[min(100%,300px)] shrink-0 flex-col border-l border-line bg-panel shadow-[-8px_0_24px_rgba(0,0,0,0.04)] min-[960px]:static min-[960px]:top-auto min-[960px]:right-auto min-[960px]:bottom-auto min-[960px]:z-auto min-[960px]:shadow-none">
      <div className="flex h-11 shrink-0 items-center border-b border-line px-4 text-[13px] font-semibold text-ink min-[960px]:hidden">
        Look
        <button
          type="button"
          className="ml-auto flex h-7 w-7 items-center justify-center rounded-md text-muted hover:bg-surface hover:text-ink"
          aria-label="Close properties"
          onClick={onClose}
        >
          ×
        </button>
      </div>
      <div className="min-h-0 flex-1 overflow-y-auto px-4 py-4">
        <div className="text-[13px] font-semibold text-ink">Look</div>
        <div className="mt-2 flex gap-1.5 overflow-x-auto pb-1">
          {PRESETS.map((preset) => {
            const active = stylesMatch(doc.style, preset.style);
            return (
              <button
                key={preset.id}
                type="button"
                aria-pressed={active}
                onClick={() => onPreset(preset.style)}
                className={`h-7 shrink-0 rounded-full px-2.5 text-[12px] ${active ? "bg-ink text-white" : "bg-surface text-ink hover:bg-[#e7e7e7]"}`}
              >
                {preset.name}
              </button>
            );
          })}
        </div>

        <div className="mt-4 text-[13px] font-semibold text-ink">Background</div>
        <div className="mt-2 mb-1 text-[11px] text-muted">Colour</div>
        <Swatches
          label="Background colour"
          colors={COLORS}
          value={doc.style.background.kind === "color" ? doc.style.background.color : undefined}
          onChange={(color) => onBackground({ kind: "color", color })}
        />
        <div className="mt-3 mb-1 text-[11px] text-muted">Gradient</div>
        <div className="grid grid-cols-6 gap-1.5">
          {GRADIENTS.map((gradient) => {
            const active =
              doc.style.background.kind === "gradient" &&
              doc.style.background.from === gradient.from &&
              doc.style.background.to === gradient.to;
            return (
              <button
                key={gradient.name}
                type="button"
                aria-label={gradient.name}
                aria-pressed={active}
                title={gradient.name}
                className={`h-8 rounded-md border ${active ? "border-accent" : "border-black/10"}`}
                style={{ background: `linear-gradient(${gradient.angle}deg, ${gradient.from}, ${gradient.to})` }}
                onClick={() => onBackground({ kind: "gradient", from: gradient.from, to: gradient.to, angle: gradient.angle })}
              />
            );
          })}
        </div>
        <div className="mt-3 mb-1 text-[11px] text-muted">Pattern</div>
        <div className="grid grid-cols-3 gap-1.5">
          {WALLPAPERS.map((wallpaper) => {
            const active = doc.style.background.kind === "wallpaper" && doc.style.background.id === wallpaper.id;
            return (
              <button
                key={wallpaper.id}
                type="button"
                aria-pressed={active}
                className={`h-12 rounded-md border text-[10px] text-ink ${active ? "border-accent" : "border-black/10"}`}
                style={{
                  background: backgroundCss({ kind: "wallpaper", id: wallpaper.id }),
                  backgroundSize: "8px 8px",
                }}
                onClick={() => onBackground({ kind: "wallpaper", id: wallpaper.id })}
              >
                <span className="rounded bg-white/85 px-1 py-0.5">{wallpaper.name}</span>
              </button>
            );
          })}
        </div>

        <div className="mt-4 mb-1.5 text-[12px] text-ink">Frame</div>
        <Segmented
          label="Screenshot frame"
          value={doc.style.frame}
          options={[
            { value: "none" as FrameStyle, label: "None" },
            { value: "browser" as FrameStyle, label: "Browser" },
            { value: "desktop" as FrameStyle, label: "Window" },
          ]}
          onChange={(frame) => {
            onGestureStart();
            onStyleLive({ frame });
            onGestureEnd();
          }}
        />

        <div className="mt-4 flex flex-col gap-3">
          <SliderField
            label="Padding"
            min={0}
            max={200}
            step={1}
            value={doc.style.padding}
            onLive={(padding) => onStyleLive({ padding })}
            onGestureStart={onGestureStart}
            onGestureEnd={onGestureEnd}
          />
          <SliderField
            label="Corners"
            min={0}
            max={64}
            value={doc.style.radius}
            onLive={(radius) => onStyleLive({ radius })}
            onGestureStart={onGestureStart}
            onGestureEnd={onGestureEnd}
          />
          <SliderField
            label="Shadow"
            min={0}
            max={100}
            value={doc.style.shadow}
            onLive={(shadow) => onStyleLive({ shadow })}
            onGestureStart={onGestureStart}
            onGestureEnd={onGestureEnd}
          />
        </div>

        {showMark ? (
          <div className="mt-4 flex flex-col gap-3 border-t border-line pt-4">
            <div className="text-[12px] text-ink">Mark</div>
            <Swatches
              label="Annotation colour"
              colors={INK_COLORS}
              value={selected?.color ?? brush.color}
              onChange={(color) => {
                onGestureStart();
                onBrush({ color });
                if (selected) onPatchSelected({ color });
                onGestureEnd();
              }}
            />
            {showTextSize ? (
              <Segmented
                label="Text size"
                value={String(selected?.type === "text" ? selected.fontSize : brush.fontSize)}
                options={FONT_SIZES.map((size) => ({ value: String(size), label: String(size) }))}
                onChange={(value) => {
                  const fontSize = Number(value);
                  onGestureStart();
                  onBrush({ fontSize });
                  if (selected?.type === "text") onPatchSelected({ fontSize });
                  onGestureEnd();
                }}
              />
            ) : (
              <Segmented
                label="Stroke width"
                value={String(selected && "strokeWidth" in selected ? selected.strokeWidth : brush.strokeWidth)}
                options={STROKE_WIDTHS.map((width) => ({ value: String(width), label: String(width) }))}
                onChange={(value) => {
                  const strokeWidth = Number(value);
                  onGestureStart();
                  onBrush({ strokeWidth });
                  if (selected) onPatchSelected({ strokeWidth });
                  onGestureEnd();
                }}
              />
            )}
            {tool === "pixelate" || selected?.type === "pixelate" ? (
              <SliderField
                label="Pixel block"
                min={6}
                max={40}
                value={selected?.type === "pixelate" ? selected.amount : brush.pixelSize}
                onGestureStart={onGestureStart}
                onGestureEnd={onGestureEnd}
                onLive={(value) => {
                  onBrush({ pixelSize: value });
                  if (selected?.type === "pixelate") onPatchSelected({ amount: value });
                }}
              />
            ) : null}
            {tool === "blur" || selected?.type === "blur" ? (
              <SliderField
                label="Blur radius"
                min={2}
                max={40}
                value={selected?.type === "blur" ? selected.amount : brush.blur}
                onGestureStart={onGestureStart}
                onGestureEnd={onGestureEnd}
                onLive={(value) => {
                  onBrush({ blur: value });
                  if (selected?.type === "blur") onPatchSelected({ amount: value });
                }}
              />
            ) : null}
            <button
              type="button"
              className="h-8 rounded-md border border-line text-[12px] hover:bg-surface disabled:opacity-40"
              disabled={!selected}
              onClick={onDeleteSelected}
            >
              Delete selected
            </button>
          </div>
        ) : null}

        <div className="mt-4 flex flex-col gap-2">
          <button
            type="button"
            className="h-8 rounded-md text-[12px] text-muted hover:bg-surface hover:text-ink disabled:opacity-40"
            disabled={!doc.crop}
            onClick={onResetCrop}
          >
            Reset crop
          </button>
          <button
            type="button"
            className="h-8 rounded-md text-[12px] text-muted hover:bg-surface hover:text-ink disabled:opacity-40"
            disabled={redactionCount === 0}
            onClick={onRemoveRedactions}
          >
            Remove redactions{redactionCount ? ` (${redactionCount})` : ""}
          </button>
        </div>
      </div>
      <div className="shrink-0 border-t border-line p-3">
        <button
          type="button"
          className="h-10 w-full rounded-lg bg-accent text-[13px] font-medium text-white hover:bg-[#2d6ae0]"
          onClick={onDone}
        >
          Done
        </button>
      </div>
    </aside>
  );
}
