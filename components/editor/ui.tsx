"use client";

import { useState, type ReactNode } from "react";
import { clamp } from "@/lib/geometry";
import { IconChevron } from "./icons";

export function Section({
  title,
  children,
  defaultOpen = true,
}: {
  title: string;
  children: ReactNode;
  defaultOpen?: boolean;
}) {
  const [open, setOpen] = useState(defaultOpen);
  return (
    <section className="border-b border-line">
      <button
        type="button"
        className="flex w-full items-center justify-between px-4 py-2.5 text-[11px] font-medium tracking-[0.08em] text-muted uppercase hover:text-ink"
        aria-expanded={open}
        onClick={() => setOpen((value) => !value)}
      >
        {title}
        <IconChevron open={open} size={14} />
      </button>
      {open ? <div className="px-4 pb-4">{children}</div> : null}
    </section>
  );
}

export function Segmented<T extends string>({
  value,
  options,
  onChange,
  label,
}: {
  value: T;
  options: { value: T; label: string }[];
  onChange: (value: T) => void;
  label: string;
}) {
  return (
    <div
      role="radiogroup"
      aria-label={label}
      className="grid gap-1 rounded-lg bg-surface p-1"
      style={{ gridTemplateColumns: `repeat(${options.length}, minmax(0, 1fr))` }}
    >
      {options.map((option) => {
        const selected = option.value === value;
        return (
          <button
            key={option.value}
            type="button"
            role="radio"
            aria-checked={selected}
            className={`h-7 rounded-md text-[12px] ${selected ? "bg-panel text-ink shadow-[0_1px_1px_rgba(0,0,0,0.04)] ring-1 ring-line" : "text-muted hover:text-ink"}`}
            onClick={() => onChange(option.value)}
          >
            {option.label}
          </button>
        );
      })}
    </div>
  );
}

export function SliderField({
  label,
  value,
  min,
  max,
  step = 1,
  onLive,
  onGestureStart,
  onGestureEnd,
}: {
  label: string;
  value: number;
  min: number;
  max: number;
  step?: number;
  onLive: (value: number) => void;
  onGestureStart: () => void;
  onGestureEnd: () => void;
}) {
  const commit = (next: number) => onLive(clamp(next, min, max));
  return (
    <label className="block">
      <span className="mb-1.5 flex items-center justify-between gap-3 text-[12px]">
        <span className="text-ink">{label}</span>
        <input
          type="number"
          inputMode="numeric"
          aria-label={`${label} value`}
          min={min}
          max={max}
          step={step}
          value={value}
          className="w-14 rounded-md border border-line bg-surface px-1.5 py-0.5 text-right text-[12px] text-ink outline-none focus:border-accent"
          onFocus={onGestureStart}
          onBlur={onGestureEnd}
          onChange={(event) => {
            const next = Number(event.target.value);
            if (Number.isFinite(next)) commit(next);
          }}
        />
      </span>
      <input
        type="range"
        aria-label={label}
        min={min}
        max={max}
        step={step}
        value={value}
        onPointerDown={(event) => {
          event.currentTarget.setPointerCapture(event.pointerId);
          onGestureStart();
        }}
        onPointerUp={onGestureEnd}
        onPointerCancel={onGestureEnd}
        onChange={(event) => commit(Number(event.target.value))}
      />
    </label>
  );
}

export function Swatches({
  colors,
  value,
  onChange,
  label,
}: {
  colors: string[];
  value?: string;
  onChange: (color: string) => void;
  label: string;
}) {
  return (
    <div className="flex flex-wrap gap-1.5" role="listbox" aria-label={label}>
      {colors.map((color) => {
        const selected = value?.toLowerCase() === color.toLowerCase();
        const checker = color === "transparent";
        return (
          <button
            key={color}
            type="button"
            role="option"
            aria-selected={selected}
            aria-label={checker ? "Transparent" : color}
            title={checker ? "Transparent" : color}
            className={`h-6 w-6 rounded-full border ${selected ? "border-accent ring-2 ring-accent/30" : "border-line"}`}
            style={{
              background: checker
                ? "repeating-conic-gradient(#e5e5e5 0% 25%, #fff 0% 50%) 0 0 / 8px 8px"
                : color,
            }}
            onClick={() => onChange(color)}
          />
        );
      })}
    </div>
  );
}
