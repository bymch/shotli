"use client";

import { backgroundCss, COLORS, FONT_SIZES, GRADIENTS, INK_COLORS, PRESETS, STROKE_WIDTHS, stylesMatch, WALLPAPERS } from "@/lib/presets";
import type { Annotation, Brush, Doc, FrameStyle, Style, Tool } from "@/lib/types";
import { ToolIcon } from "./icons";
import { Section, Segmented, SliderField, Swatches } from "./ui";

const TOOLS: { id: Tool; label: string }[] = [
  { id: "select", label: "Select and move" },
  { id: "rect", label: "Rectangle outline" },
  { id: "rect-fill", label: "Filled rectangle" },
  { id: "circle", label: "Circle" },
  { id: "line", label: "Line" },
  { id: "arrow", label: "Arrow" },
  { id: "draw", label: "Freehand drawing" },
  { id: "text", label: "Text" },
  { id: "marker", label: "Numbered marker" },
  { id: "pixelate", label: "Pixelate" },
  { id: "blur", label: "Blur" },
];

export function Sidebar({
  open,
  doc,
  tool,
  brush,
  onTool,
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
}: {
  open: boolean;
  doc: Doc;
  tool: Tool;
  brush: Brush;
  onTool: (tool: Tool) => void;
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
}) {
  if (!open) return null;
  const selected = doc.annotations.find((annotation) => annotation.id === doc.selectedId) ?? null;
  const redactionCount = doc.annotations.filter(
    (annotation) => annotation.type === "pixelate" || annotation.type === "blur",
  ).length;
  const backgroundKind = doc.style.background.kind;
  const showTextSize = tool === "text" || selected?.type === "text";

  return (
    <aside className="absolute inset-y-0 right-0 z-20 flex w-[min(100%,340px)] shrink-0 flex-col border-l border-line bg-panel shadow-[-8px_0_24px_rgba(0,0,0,0.04)] min-[960px]:static min-[960px]:shadow-none">
      <div className="flex h-12 shrink-0 items-center border-b border-line px-4 text-[12px] font-medium text-ink">
        Properties
      </div>
      <div className="min-h-0 flex-1 overflow-y-auto">
        <Section title="Presets">
          <div className="grid grid-cols-2 gap-2">
            {PRESETS.map((preset) => {
              const active = stylesMatch(doc.style, preset.style);
              return (
                <button
                  key={preset.id}
                  type="button"
                  aria-pressed={active}
                  onClick={() => onPreset(preset.style)}
                  className={`rounded-lg border p-1.5 text-left hover:border-[#c8c8c8] ${active ? "border-accent" : "border-line"}`}
                >
                  <span
                    className="flex h-11 items-center justify-center rounded-md border border-black/5"
                    style={{
                      background: backgroundCss(preset.style.background),
                      backgroundSize: preset.style.background.kind === "wallpaper" ? "10px 10px" : undefined,
                    }}
                  >
                    <span
                      className="block h-5 w-7 bg-white shadow-[0_2px_6px_rgba(0,0,0,0.12)]"
                      style={{ borderRadius: Math.min(6, preset.style.radius / 3) }}
                    />
                  </span>
                  <span className="mt-1 block px-0.5 text-[11px] text-ink">{preset.name}</span>
                </button>
              );
            })}
          </div>
        </Section>

        <Section title="Tools">
          <div className="grid grid-cols-4 gap-1" role="toolbar" aria-label="Annotation tools">
            {TOOLS.map((item) => (
              <button
                key={item.id}
                type="button"
                aria-label={item.label}
                aria-pressed={tool === item.id}
                title={item.label}
                onClick={() => onTool(item.id)}
                className={`flex h-9 items-center justify-center rounded-md text-ink hover:bg-surface ${tool === item.id ? "bg-selected" : ""}`}
              >
                <ToolIcon tool={item.id} />
              </button>
            ))}
          </div>
        </Section>

        <Section title="Smart redaction" defaultOpen>
          <p className="mb-3 text-[12px] leading-5 text-muted">
            Drag a rectangle with Pixelate or Blur. The effect is painted into the exported PNG, not laid on top of it.
          </p>
          <div className="flex flex-col gap-3">
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
            <div className="flex gap-2">
              <button type="button" className="h-8 flex-1 rounded-md bg-selected text-[12px] hover:bg-[#e1e1e1]" onClick={() => onTool("pixelate")}>
                Pixelate
              </button>
              <button type="button" className="h-8 flex-1 rounded-md bg-selected text-[12px] hover:bg-[#e1e1e1]" onClick={() => onTool("blur")}>
                Blur
              </button>
            </div>
            <button
              type="button"
              className="h-8 rounded-md border border-line text-[12px] text-ink hover:bg-surface disabled:opacity-40"
              disabled={redactionCount === 0}
              onClick={onRemoveRedactions}
            >
              Remove redactions{redactionCount ? ` (${redactionCount})` : ""}
            </button>
          </div>
        </Section>

        <Section title="Style">
          <div className="flex flex-col gap-3">
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
              <div>
                <div className="mb-1.5 text-[12px] text-ink">Text size</div>
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
              </div>
            ) : (
              <div>
                <div className="mb-1.5 text-[12px] text-ink">Stroke</div>
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
              </div>
            )}
            <button
              type="button"
              className="h-8 rounded-md border border-line text-[12px] hover:bg-surface disabled:opacity-40"
              disabled={!selected}
              onClick={onDeleteSelected}
            >
              Delete selected
            </button>
          </div>
        </Section>

        <Section title="Background">
          <div className="flex flex-col gap-3">
            <Segmented
              label="Background type"
              value={backgroundKind}
              options={[
                { value: "color", label: "Colour" },
                { value: "gradient", label: "Gradient" },
                { value: "wallpaper", label: "Wallpaper" },
              ]}
              onChange={(kind) => {
                if (kind === "color") onBackground({ kind: "color", color: "#F1F1F1" });
                if (kind === "gradient") onBackground({ kind: "gradient", ...GRADIENTS[0] });
                if (kind === "wallpaper") onBackground({ kind: "wallpaper", id: "dots" });
              }}
            />
            {doc.style.background.kind === "color" ? (
              <Swatches
                label="Background colour"
                colors={COLORS}
                value={doc.style.background.color}
                onChange={(color) => onBackground({ kind: "color", color })}
              />
            ) : null}
            {doc.style.background.kind === "gradient" ? (
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
                      className={`h-10 rounded-md border ${active ? "border-accent" : "border-line"}`}
                      style={{ background: `linear-gradient(${gradient.angle}deg, ${gradient.from}, ${gradient.to})` }}
                      onClick={() => onBackground({ kind: "gradient", from: gradient.from, to: gradient.to, angle: gradient.angle })}
                    />
                  );
                })}
              </div>
            ) : null}
            {doc.style.background.kind === "wallpaper" ? (
              <div className="grid grid-cols-3 gap-2">
                {WALLPAPERS.map((wallpaper) => {
                  const active = doc.style.background.kind === "wallpaper" && doc.style.background.id === wallpaper.id;
                  return (
                    <button
                      key={wallpaper.id}
                      type="button"
                      aria-pressed={active}
                      className={`h-10 rounded-md border text-[10px] text-ink ${active ? "border-accent" : "border-line"}`}
                      style={{
                        background: backgroundCss({ kind: "wallpaper", id: wallpaper.id }),
                        backgroundSize: "8px 8px",
                      }}
                      onClick={() => onBackground({ kind: "wallpaper", id: wallpaper.id })}
                    >
                      <span className="rounded bg-white/80 px-1 py-0.5">{wallpaper.name}</span>
                    </button>
                  );
                })}
              </div>
            ) : null}
          </div>
        </Section>

        <Section title="Layout">
          <div className="flex flex-col gap-3">
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
              label="Corner radius"
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
            <div>
              <div className="mb-1.5 text-[12px] text-ink">Frame</div>
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
            </div>
            <div>
              <div className="mb-1.5 text-[12px] text-ink">Background</div>
              <Swatches
                label="Layout background"
                colors={COLORS.slice(0, 8)}
                value={doc.style.background.kind === "color" ? doc.style.background.color : undefined}
                onChange={(color) => onBackground({ kind: "color", color })}
              />
            </div>
            <button
              type="button"
              className="h-8 rounded-md border border-line text-[12px] hover:bg-surface disabled:opacity-40"
              disabled={!doc.crop}
              onClick={onResetCrop}
            >
              Reset crop
            </button>
          </div>
        </Section>
      </div>
    </aside>
  );
}
