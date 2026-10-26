"use client";

import { useEffect, useRef } from "react";
import { backgroundCss, COLORS, FONT_SIZES, GRADIENTS, INK_COLORS, PRESETS, SCENES, STROKE_WIDTHS, stylesMatch, WALLPAPERS } from "@/lib/presets";
import { drawScene, isScene, type SceneId } from "@/lib/scenes";
import type { Annotation, Brush, Doc, FrameStyle, Style, Tool, WallpaperId } from "@/lib/types";
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
    <aside className="absolute top-12 right-0 bottom-0 z-20 flex w-[min(100%,348px)] shrink-0 flex-col bg-workspace p-2.5 min-[960px]:static min-[960px]:top-auto min-[960px]:right-auto min-[960px]:bottom-auto min-[960px]:z-auto">
      <div className="flex min-h-0 flex-1 flex-col overflow-hidden rounded-2xl border border-black/[0.06] bg-white shadow-[0_10px_28px_rgba(0,0,0,0.06)]">
      <div className="flex h-11 shrink-0 items-center border-b border-line px-3.5 text-[13px] font-semibold text-ink min-[960px]:hidden">
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
      <div className="min-h-0 flex-1 overflow-y-auto px-3.5 py-3.5">
        <div className="text-[10px] font-semibold tracking-[0.08em] text-muted uppercase">Look</div>
        <div className="mt-2 grid grid-cols-2 gap-2.5">
          {PRESETS.map((preset) => {
            const active = stylesMatch(doc.style, preset.style);
            return (
              <button
                key={preset.id}
                type="button"
                aria-pressed={active}
                onClick={() => onPreset(preset.style)}
                className="text-center"
              >
                <span
                  className={`relative block h-[74px] overflow-hidden rounded-[10px] border-2 ${active ? "border-accent" : "border-black/10"}`}
                  style={{
                    background: backgroundCss(preset.style.background),
                    backgroundSize: "8px 8px",
                  }}
                >
                  <span className="absolute inset-x-3 top-2.5 bottom-2.5 rounded-[4px] bg-white shadow-[0_4px_10px_rgba(0,0,0,0.16)]" />
                  {preset.style.frame !== "none" ? (
                    <span className="absolute top-[14px] left-[16px] flex gap-[2px]">
                      <span className="h-[3.5px] w-[3.5px] rounded-full bg-[#ff5f57]" />
                      <span className="h-[3.5px] w-[3.5px] rounded-full bg-[#febc2e]" />
                      <span className="h-[3.5px] w-[3.5px] rounded-full bg-[#28c840]" />
                    </span>
                  ) : null}
                </span>
                <span className={`mt-1 block text-[11px] ${active ? "font-semibold text-ink" : "text-muted"}`}>{preset.name}</span>
              </button>
            );
          })}
        </div>

        <div className="mt-5 text-[10px] font-semibold tracking-[0.08em] text-muted uppercase">Background</div>
        <div className="mt-3 mb-1.5 text-[10px] font-semibold tracking-[0.08em] text-muted uppercase">Colour</div>
        <Swatches
          label="Background colour"
          colors={COLORS}
          value={doc.style.background.kind === "color" ? doc.style.background.color : undefined}
          onChange={(color) => onBackground({ kind: "color", color })}
        />
        <FillGrid title="Scenes" items={SCENES} doc={doc} onBackground={onBackground} columns={2} height="h-[86px]" />
        <div className="mt-4 mb-2 text-[10px] font-semibold tracking-[0.08em] text-muted uppercase">Gradient</div>
        <div className="grid grid-cols-3 gap-2">
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
                className={`h-12 rounded-[10px] border-2 ${active ? "border-accent" : "border-black/10"}`}
                style={{ background: `linear-gradient(${gradient.angle}deg, ${gradient.from}, ${gradient.to})` }}
                onClick={() => onBackground({ kind: "gradient", from: gradient.from, to: gradient.to, angle: gradient.angle })}
              />
            );
          })}
        </div>
        <FillGrid title="Pattern" items={WALLPAPERS} doc={doc} onBackground={onBackground} height="h-12" />

        <div className="mt-5 mb-2 text-[10px] font-semibold tracking-[0.08em] text-muted uppercase">Frame</div>
        <div className="grid grid-cols-3 gap-2">
          {(
            [
              { value: "none" as FrameStyle, label: "None" },
              { value: "browser" as FrameStyle, label: "Browser" },
              { value: "desktop" as FrameStyle, label: "Window" },
            ]
          ).map((option) => {
            const active = doc.style.frame === option.value;
            return (
              <button
                key={option.value}
                type="button"
                aria-pressed={active}
                className="text-center"
                onClick={() => {
                  onGestureStart();
                  onStyleLive({ frame: option.value });
                  onGestureEnd();
                }}
              >
                <span className={`relative flex h-10 items-center justify-center rounded-lg border-2 bg-[#f5f5f6] ${active ? "border-accent" : "border-black/5"}`}>
                  <span className="relative h-5 w-8 rounded-[3px] bg-white shadow-[0_1px_2px_rgba(0,0,0,0.12)]">
                    {option.value !== "none" ? (
                      <span className="absolute top-1 left-1 flex gap-[2px]">
                        <span className="h-1 w-1 rounded-full bg-[#ff5f57]" />
                        <span className="h-1 w-1 rounded-full bg-[#febc2e]" />
                        <span className="h-1 w-1 rounded-full bg-[#28c840]" />
                      </span>
                    ) : null}
                  </span>
                </span>
                <span className={`mt-1 block text-[10px] ${active ? "font-semibold text-ink" : "text-muted"}`}>{option.label}</span>
              </button>
            );
          })}
        </div>

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
      <div className="shrink-0 px-3.5 pt-2 pb-3.5">
        <button
          type="button"
          className="h-9 w-full rounded-full bg-accent text-[13px] font-medium text-white hover:bg-[#2d6ae0]"
          onClick={onDone}
        >
          Done
        </button>
      </div>
      </div>
    </aside>
  );
}

function FillGrid({
  title,
  items,
  doc,
  onBackground,
  columns = 3,
  height,
}: {
  title: string;
  items: { id: WallpaperId; name: string }[];
  doc: Doc;
  onBackground: (background: Style["background"]) => void;
  columns?: 2 | 3;
  height: string;
}) {
  return (
    <>
      <div className="mt-4 mb-2 text-[10px] font-semibold tracking-[0.08em] text-muted uppercase">{title}</div>
      <div className={`grid gap-2.5 ${columns === 2 ? "grid-cols-2" : "grid-cols-3"}`}>
        {items.map((item) => {
          const active = doc.style.background.kind === "wallpaper" && doc.style.background.id === item.id;
          const scene = isScene(item.id);
          return (
            <button
              key={item.id}
              type="button"
              aria-pressed={active}
              className="text-center"
              onClick={() => onBackground({ kind: "wallpaper", id: item.id })}
            >
              <span
                className={`relative block overflow-hidden rounded-[10px] border-2 ${height} ${active ? "border-accent" : "border-black/10"}`}
                style={
                  scene
                    ? undefined
                    : {
                        background: backgroundCss({ kind: "wallpaper", id: item.id }),
                        backgroundSize: "8px 8px",
                      }
                }
              >
                {isScene(item.id) ? <SceneThumb id={item.id} /> : null}
              </span>
              <span className={`mt-1 block text-[11px] ${active ? "font-semibold text-ink" : "text-muted"}`}>{item.name}</span>
            </button>
          );
        })}
      </div>
    </>
  );
}

function SceneThumb({ id }: { id: SceneId }) {
  const ref = useRef<HTMLCanvasElement>(null);
  useEffect(() => {
    const canvas = ref.current;
    if (!canvas) return;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;
    drawScene(ctx, id, canvas.width, canvas.height);
  }, [id]);
  return <canvas ref={ref} width={240} height={144} className="absolute inset-0 h-full w-full" aria-hidden />;
}
