"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import {
  almostSameRect,
  clampRect,
  constrainBox,
  constrainLine,
  cursorForHandle,
  finalizeAnnotation,
  hitHandle,
  hitTest,
  isBigEnough,
  normalizeRect,
  resizeAnnotation,
  translateAnnotation,
} from "@/lib/geometry";
import { activeCrop, compositionOf, contentSize } from "@/lib/layout";
import { paintBackground, renderComposition } from "@/lib/render";
import type { Annotation, Background, Brush, Doc, Handle, Rect, Tool } from "@/lib/types";
import { pictureChanged, snapshot, type Snapshot } from "@/lib/types";
import { ToolIcon } from "./icons";

type View = { mode: "fit" | "manual"; zoom: number; panX: number; panY: number };

type Drag =
  | { kind: "pan"; sx: number; sy: number; panX: number; panY: number; zoom: number }
  | { kind: "move"; id: string; sx: number; sy: number; origin: Annotation; before: Snapshot }
  | { kind: "resize"; id: string; handle: Handle; sx: number; sy: number; origin: Annotation; before: Snapshot }
  | { kind: "new"; start: { x: number; y: number }; annotation: Annotation; before: Snapshot }
  | { kind: "crop"; start: { x: number; y: number }; rect: Rect; before: Snapshot };

type TextSession = {
  token: number;
  id: string | null;
  x: number;
  y: number;
  text: string;
  color: string;
  fontSize: number;
  before: Snapshot | null;
};

export function Workspace({
  doc,
  tool,
  brush,
  notice,
  fileDrag,
  onNotice,
  onCommit,
  onLive,
  onTool,
}: {
  doc: Doc;
  tool: Tool;
  brush: Brush;
  notice: string | null;
  fileDrag: boolean;
  onNotice: (message: string | null) => void;
  onCommit: (next: Doc, before: Snapshot) => void;
  onLive: (next: Doc) => void;
  onTool: (tool: Tool) => void;
}) {
  const workspaceRef = useRef<HTMLDivElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const textRef = useRef<HTMLTextAreaElement>(null);
  const docRef = useRef(doc);
  const toolRef = useRef(tool);
  const brushRef = useRef(brush);
  const dragRef = useRef<Drag | null>(null);
  const spaceRef = useRef(false);
  const [view, setView] = useState<View>({ mode: "fit", zoom: 1, panX: 0, panY: 0 });
  const viewRef = useRef(view);
  const [size, setSize] = useState({ w: 0, h: 0 });
  const sizeRef = useRef(size);
  const [draft, setDraft] = useState<Annotation | null>(null);
  const [cropDraft, setCropDraft] = useState<Rect | null>(null);
  const [session, setSession] = useState<TextSession | null>(null);
  const sessionRef = useRef<TextSession | null>(null);
  const textOpenedAt = useRef(0);

  const composition = compositionOf(doc);
  const scale = computeScale(view, size, composition.compW, composition.compH);
  const pan = computePan(view, size, composition.compW, composition.compH, scale);
  const scaleRef = useRef(scale);

  useEffect(() => {
    docRef.current = doc;
    toolRef.current = tool;
    brushRef.current = brush;
    viewRef.current = view;
    sizeRef.current = size;
    sessionRef.current = session;
    scaleRef.current = scale;
  });

  useEffect(() => {
    const element = workspaceRef.current;
    if (!element) return;
    const measure = () => {
      const next = { w: element.clientWidth, h: element.clientHeight };
      sizeRef.current = next;
      setSize(next);
    };
    measure();
    const observer = new ResizeObserver(measure);
    observer.observe(element);
    return () => observer.disconnect();
  }, []);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas || !doc.image) return;
    const dpr = composition.compW * composition.compH > 4_000_000 ? 1 : Math.min(window.devicePixelRatio || 1, 2);
    canvas.width = Math.max(1, Math.round(composition.compW * dpr));
    canvas.height = Math.max(1, Math.round(composition.compH * dpr));
    const ctx = canvas.getContext("2d");
    if (!ctx) return;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    const fontFamily = getComputedStyle(document.body).fontFamily;
    renderComposition(ctx, doc, {
      fontFamily,
      interactive: true,
      zoom: scale,
      draft,
      cropDraft,
      hideTextId: session?.id ?? null,
      background: false,
    });
  }, [doc, draft, cropDraft, scale, session?.id, composition.compW, composition.compH]);

  const textToken = session?.token ?? 0;
  useEffect(() => {
    if (!textToken) return;
    textRef.current?.focus();
  }, [textToken]);

  const fit = useCallback(() => {
    const next = { mode: "fit" as const, zoom: 1, panX: 0, panY: 0 };
    viewRef.current = next;
    setView(next);
  }, []);

  const actualSize = useCallback(() => {
    const frame = compositionOf(docRef.current);
    const box = sizeRef.current;
    const next = {
      mode: "manual" as const,
      zoom: 1,
      panX: (box.w - frame.compW) / 2,
      panY: (box.h - frame.compH) / 2,
    };
    viewRef.current = next;
    setView(next);
  }, []);

  const zoomAt = useCallback((factor: number, anchorX: number, anchorY: number) => {
    const current = scaleRef.current;
    const frame = compositionOf(docRef.current);
    const placement = computePan(viewRef.current, sizeRef.current, frame.compW, frame.compH, current);
    const nextZoom = clampZoom(current * factor);
    const relX = (anchorX - placement.x) / current;
    const relY = (anchorY - placement.y) / current;
    const next = { mode: "manual" as const, zoom: nextZoom, panX: anchorX - relX * nextZoom, panY: anchorY - relY * nextZoom };
    viewRef.current = next;
    setView(next);
  }, []);

  useEffect(() => {
    const element = workspaceRef.current;
    if (!element) return;
    const onWheel = (event: WheelEvent) => {
      if (!docRef.current.image) return;
      event.preventDefault();
      const rect = element.getBoundingClientRect();
      if (event.ctrlKey || event.metaKey) {
        zoomAt(event.deltaY < 0 ? 1.06 : 0.94, event.clientX - rect.left, event.clientY - rect.top);
        return;
      }
      const current = scaleRef.current;
      const frame = compositionOf(docRef.current);
      const placement = computePan(viewRef.current, sizeRef.current, frame.compW, frame.compH, current);
      const next = {
        mode: "manual" as const,
        zoom: current,
        panX: placement.x - event.deltaX,
        panY: placement.y - event.deltaY,
      };
      viewRef.current = next;
      setView(next);
    };
    element.addEventListener("wheel", onWheel, { passive: false });
    return () => element.removeEventListener("wheel", onWheel);
  }, [zoomAt]);

  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      if (isTyping(event.target)) return;
      const meta = event.metaKey || event.ctrlKey;
      if (event.code === "Space") {
        spaceRef.current = true;
        event.preventDefault();
      } else if (meta && event.key === "0") {
        event.preventDefault();
        fit();
      } else if (meta && event.key === "1") {
        event.preventDefault();
        actualSize();
      } else if (meta && (event.key === "=" || event.key === "+")) {
        event.preventDefault();
        zoomAt(1.1, sizeRef.current.w / 2, sizeRef.current.h / 2);
      } else if (meta && event.key === "-") {
        event.preventDefault();
        zoomAt(1 / 1.1, sizeRef.current.w / 2, sizeRef.current.h / 2);
      }
    };
    const onKeyUp = (event: KeyboardEvent) => {
      if (event.code === "Space") spaceRef.current = false;
    };
    window.addEventListener("keydown", onKeyDown);
    window.addEventListener("keyup", onKeyUp);
    return () => {
      window.removeEventListener("keydown", onKeyDown);
      window.removeEventListener("keyup", onKeyUp);
    };
  }, [actualSize, fit, zoomAt]);

  function commitText() {
    const nextSession = sessionRef.current;
    if (!nextSession) return;
    sessionRef.current = null;
    setSession(null);
    const text = nextSession.text.replace(/\s+$/, "");
    const current = docRef.current;
    if (nextSession.id) {
      const before = nextSession.before ?? snapshot(current);
      if (!text.trim()) {
        onCommit(
          {
            ...current,
            annotations: current.annotations.filter((annotation) => annotation.id !== nextSession.id),
            selectedId: current.selectedId === nextSession.id ? null : current.selectedId,
          },
          before,
        );
      } else {
        const next = {
          ...current,
          annotations: current.annotations.map((annotation) =>
            annotation.id === nextSession.id && annotation.type === "text" ? { ...annotation, text } : annotation,
          ),
        };
        if (pictureChanged(before, snapshot(next))) onCommit(next, before);
      }
    } else if (text.trim()) {
      const annotation: Annotation = {
        id: crypto.randomUUID(),
        type: "text",
        x: nextSession.x,
        y: nextSession.y,
        text,
        color: nextSession.color,
        strokeWidth: brushRef.current.strokeWidth,
        fontSize: nextSession.fontSize,
      };
      onCommit(
        { ...current, annotations: [...current.annotations, annotation], selectedId: annotation.id },
        snapshot(current),
      );
    }
  }

  function cancelText() {
    const currentSession = sessionRef.current;
    if (!currentSession) return;
    sessionRef.current = null;
    setSession(null);
    if (currentSession.id && currentSession.before) {
      onLive({
        ...docRef.current,
        annotations: currentSession.before.annotations,
        selectedId: currentSession.before.selectedId,
        crop: currentSession.before.crop,
        style: currentSession.before.style,
      });
    }
  }

  function clientToBitmap(clientX: number, clientY: number) {
    const canvas = canvasRef.current;
    const image = docRef.current.image;
    if (!canvas || !image) return null;
    const rect = canvas.getBoundingClientRect();
    if (rect.width === 0 || rect.height === 0) return null;
    const frame = compositionOf(docRef.current);
    const crop = activeCrop(docRef.current);
    if (!crop) return null;
    const compX = ((clientX - rect.left) / rect.width) * frame.compW;
    const compY = ((clientY - rect.top) / rect.height) * frame.compH;
    return { x: crop.x + (compX - frame.image.x), y: crop.y + (compY - frame.image.y) };
  }

  function insideImage(point: { x: number; y: number }) {
    const crop = activeCrop(docRef.current);
    if (!crop) return false;
    return point.x >= crop.x && point.y >= crop.y && point.x <= crop.x + crop.w && point.y <= crop.y + crop.h;
  }

  function updateAnnotation(annotation: Annotation) {
    onLive({
      ...docRef.current,
      annotations: docRef.current.annotations.map((item) => (item.id === annotation.id ? annotation : item)),
      selectedId: annotation.id,
    });
  }

  function onPointerDown(event: React.PointerEvent<HTMLDivElement>) {
    if (event.button === 1) event.preventDefault();
    if (event.button === 1 || spaceRef.current) {
      const frame = compositionOf(docRef.current);
      const current = scaleRef.current;
      const placement = computePan(viewRef.current, sizeRef.current, frame.compW, frame.compH, current);
      dragRef.current = { kind: "pan", sx: event.clientX, sy: event.clientY, panX: placement.x, panY: placement.y, zoom: current };
      event.currentTarget.setPointerCapture(event.pointerId);
      return;
    }
    if (event.button !== 0 || isUiTarget(event.target)) return;
    if (!docRef.current.image) return;
    const point = clientToBitmap(event.clientX, event.clientY);
    if (!point) return;

    if (sessionRef.current && event.target !== textRef.current) commitText();

    const currentTool = toolRef.current;
    const slop = 8 / scaleRef.current;
    if (!insideImage(point) && (currentTool === "select" || currentTool === "crop")) {
      if (currentTool === "select") {
        const frame = compositionOf(docRef.current);
        const current = scaleRef.current;
        const placement = computePan(viewRef.current, sizeRef.current, frame.compW, frame.compH, current);
        dragRef.current = { kind: "pan", sx: event.clientX, sy: event.clientY, panX: placement.x, panY: placement.y, zoom: current };
        event.currentTarget.setPointerCapture(event.pointerId);
      }
      return;
    }

    if (!insideImage(point) && currentTool !== "select") return;

    if (currentTool === "crop") {
      if (!insideImage(point)) return;
      dragRef.current = {
        kind: "crop",
        start: point,
        rect: { x: point.x, y: point.y, w: 0, h: 0 },
        before: snapshot(docRef.current),
      };
      setCropDraft({ x: point.x, y: point.y, w: 0, h: 0 });
      event.currentTarget.setPointerCapture(event.pointerId);
      return;
    }

    if (currentTool === "select") {
      const selected = docRef.current.annotations.find((annotation) => annotation.id === docRef.current.selectedId);
      if (selected) {
        const handle = hitHandle(selected, point.x, point.y, slop);
        if (handle) {
          dragRef.current = {
            kind: "resize",
            id: selected.id,
            handle,
            sx: point.x,
            sy: point.y,
            origin: selected,
            before: snapshot(docRef.current),
          };
          event.currentTarget.setPointerCapture(event.pointerId);
          return;
        }
      }
      const hit = insideImage(point) ? hitTest(docRef.current.annotations, point.x, point.y, slop) : null;
      if (hit) {
        dragRef.current = {
          kind: "move",
          id: hit.id,
          sx: point.x,
          sy: point.y,
          origin: hit,
          before: snapshot(docRef.current),
        };
        onLive({ ...docRef.current, selectedId: hit.id });
        event.currentTarget.setPointerCapture(event.pointerId);
        return;
      }
      onLive({ ...docRef.current, selectedId: null });
      return;
    }

    if (currentTool === "text") {
      if (!insideImage(point)) return;
      const token = (sessionRef.current?.token ?? 0) + 1;
      const next = {
        token,
        id: null,
        x: point.x,
        y: point.y,
        text: "",
        color: brushRef.current.color,
        fontSize: brushRef.current.fontSize,
        before: null,
      };
      textOpenedAt.current = performance.now();
      sessionRef.current = next;
      setSession(next);
      return;
    }

    if (currentTool === "marker") {
      if (!insideImage(point)) return;
      const number =
        docRef.current.annotations.reduce((max, annotation) => (annotation.type === "marker" ? Math.max(max, annotation.n) : max), 0) + 1;
      const annotation: Annotation = {
        id: crypto.randomUUID(),
        type: "marker",
        x: point.x,
        y: point.y,
        n: number,
        color: brushRef.current.color,
        strokeWidth: brushRef.current.strokeWidth,
      };
      onCommit(
        { ...docRef.current, annotations: [...docRef.current.annotations, annotation], selectedId: annotation.id },
        snapshot(docRef.current),
      );
      return;
    }

    if (!insideImage(point)) return;
    const annotation = createDraft(currentTool, point, brushRef.current);
    if (!annotation) return;
    dragRef.current = { kind: "new", start: point, annotation, before: snapshot(docRef.current) };
    setDraft(annotation);
    event.currentTarget.setPointerCapture(event.pointerId);
  }

  function onPointerMove(event: React.PointerEvent<HTMLDivElement>) {
    const drag = dragRef.current;
    if (!drag) {
      updateHoverCursor(event);
      return;
    }
    if (drag.kind === "pan") {
      const next = {
        mode: "manual" as const,
        zoom: drag.zoom,
        panX: drag.panX + (event.clientX - drag.sx),
        panY: drag.panY + (event.clientY - drag.sy),
      };
      viewRef.current = next;
      setView(next);
      return;
    }
    const point = clientToBitmap(event.clientX, event.clientY);
    if (!point) return;
    if (drag.kind === "move") {
      updateAnnotation(translateAnnotation(drag.origin, point.x - drag.sx, point.y - drag.sy));
      return;
    }
    if (drag.kind === "resize") {
      updateAnnotation(resizeAnnotation(drag.origin, drag.handle, point.x - drag.sx, point.y - drag.sy));
      return;
    }
    if (drag.kind === "crop") {
      const rect = { x: drag.start.x, y: drag.start.y, w: point.x - drag.start.x, h: point.y - drag.start.y };
      drag.rect = rect;
      setCropDraft(rect);
      return;
    }
    const next = continueDraft(drag.annotation, drag.start, point, event.shiftKey);
    drag.annotation = next;
    setDraft(next);
  }

  function onPointerUp() {
    const drag = dragRef.current;
    dragRef.current = null;
    if (!drag || drag.kind === "pan") return;
    if (drag.kind === "new") {
      const annotation = finalizeAnnotation(drag.annotation);
      setDraft(null);
      if (!isBigEnough(annotation)) return;
      onCommit(
        { ...docRef.current, annotations: [...docRef.current.annotations, annotation], selectedId: annotation.id },
        drag.before,
      );
      return;
    }
    if (drag.kind === "crop") {
      setCropDraft(null);
      const image = docRef.current.image;
      const crop = activeCrop(docRef.current);
      if (!image || !crop) return;
      const next = clampRect(normalizeRect(drag.rect.x, drag.rect.y, drag.rect.w, drag.rect.h), {
        x: 0,
        y: 0,
        w: image.width,
        h: image.height,
      });
      if (next.w < 12 || next.h < 12 || almostSameRect(next, crop)) return;
      onCommit({ ...docRef.current, crop: next }, drag.before);
      return;
    }
    const current = docRef.current.annotations.find((annotation) => annotation.id === drag.id);
    if (!current) return;
    const finalized = finalizeAnnotation(current);
    const next = {
      ...docRef.current,
      annotations: docRef.current.annotations.map((annotation) => (annotation.id === finalized.id ? finalized : annotation)),
      selectedId: finalized.id,
    };
    if (pictureChanged(drag.before, snapshot(next))) onCommit(next, drag.before);
    else onLive(next);
  }

  function updateHoverCursor(event: React.PointerEvent<HTMLDivElement>) {
    const element = workspaceRef.current;
    if (!element) return;
    if (spaceRef.current) {
      element.style.cursor = "grab";
      return;
    }
    const point = clientToBitmap(event.clientX, event.clientY);
    if (toolRef.current === "select" && point) {
      const selected = docRef.current.annotations.find((annotation) => annotation.id === docRef.current.selectedId);
      if (selected) {
        const handle = hitHandle(selected, point.x, point.y, 8 / scaleRef.current);
        if (handle) {
          element.style.cursor = cursorForHandle(handle);
          return;
        }
      }
      if (hitTest(docRef.current.annotations, point.x, point.y, 8 / scaleRef.current)) {
        element.style.cursor = "move";
        return;
      }
    }
    element.style.cursor = toolRef.current === "select" ? "default" : "crosshair";
  }

  function onDoubleClick(event: React.MouseEvent<HTMLDivElement>) {
    if (!docRef.current.image) return;
    const point = clientToBitmap(event.clientX, event.clientY);
    if (!point) return;
    const hit = hitTest(docRef.current.annotations, point.x, point.y, 8 / scaleRef.current);
    if (!hit || hit.type !== "text") return;
    const next = {
      token: (sessionRef.current?.token ?? 0) + 1,
      id: hit.id,
      x: hit.x,
      y: hit.y,
      text: hit.text,
      color: hit.color,
      fontSize: hit.fontSize,
      before: snapshot(docRef.current),
    };
    textOpenedAt.current = performance.now();
    sessionRef.current = next;
    setSession(next);
  }

  function onCanvasResize(event: React.PointerEvent<HTMLButtonElement>, handle: CanvasHandle) {
    event.stopPropagation();
    event.preventDefault();
    const startX = event.clientX;
    const startY = event.clientY;
    const before = snapshot(docRef.current);
    const frame = compositionOf(docRef.current);
    const min = contentSize(docRef.current);
    const scaleNow = Math.max(scaleRef.current, 0.05);
    const ratio = ratioFor(docRef.current.style.canvas);
    const move = (ev: PointerEvent) => {
      const dw = (ev.clientX - startX) / scaleNow;
      const dh = (ev.clientY - startY) / scaleNow;
      let width = frame.compW;
      let height = frame.compH;
      if (handle === "e" || handle === "ne" || handle === "se") width += dw;
      if (handle === "w" || handle === "nw" || handle === "sw") width -= dw;
      if (handle === "s" || handle === "se" || handle === "sw") height += dh;
      if (handle === "n" || handle === "ne" || handle === "nw") height -= dh;
      if (ratio) {
        if (handle === "n" || handle === "s") width = height * ratio;
        else height = width / ratio;
      }
      width = Math.max(min.contentW, Math.round(width));
      height = Math.max(min.contentH, Math.round(height));
      if (ratio && (handle === "n" || handle === "s")) width = Math.max(min.contentW, Math.round(height * ratio));
      if (ratio && handle !== "n" && handle !== "s") height = Math.max(min.contentH, Math.round(width / ratio));
      onLive({
        ...docRef.current,
        style: { ...docRef.current.style, canvasWidth: width, canvasHeight: height },
      });
    };
    const up = () => {
      window.removeEventListener("pointermove", move);
      window.removeEventListener("pointerup", up);
      const next = docRef.current;
      if (pictureChanged(before, snapshot(next))) onCommit(next, before);
    };
    window.addEventListener("pointermove", move);
    window.addEventListener("pointerup", up);
  }

  const crop = doc.image ? activeCrop(doc) : null;
  const textStyle =
    session && crop
      ? {
          left: composition.image.x + (session.x - crop.x),
          top: composition.image.y + (session.y - crop.y),
          fontSize: session.fontSize,
          color: session.color,
        }
      : null;

  return (
    <div
      ref={workspaceRef}
      className="workspace-grid relative min-h-0 flex-1 overflow-hidden"
      onPointerDown={onPointerDown}
      onPointerMove={onPointerMove}
      onPointerUp={onPointerUp}
      onPointerCancel={onPointerUp}
      onDoubleClick={onDoubleClick}
    >
      {notice ? (
        <div
          role="alert"
          className="absolute top-3 left-1/2 z-20 flex max-w-[min(520px,calc(100%-24px))] -translate-x-1/2 items-start gap-3 rounded-lg border border-line bg-panel px-3 py-2 text-[13px] text-ink shadow-sm"
        >
          <span>{notice}</span>
          <button type="button" className="text-muted hover:text-ink" aria-label="Dismiss notice" onClick={() => onNotice(null)}>
            ×
          </button>
        </div>
      ) : null}

      {fileDrag ? (
        <div className="pointer-events-none absolute inset-3 z-10 flex items-center justify-center rounded-xl border border-dashed border-accent bg-white/70 text-[13px] text-ink">
          Drop to import
        </div>
      ) : null}

      {doc.image ? (
        <div
          className="absolute top-0 left-0 shadow-[0_16px_40px_rgba(0,0,0,0.16)] ring-1 ring-black/10"
          style={{
            width: composition.compW,
            height: composition.compH,
            transform: `translate(${pan.x}px, ${pan.y}px) scale(${scale})`,
            transformOrigin: "top left",
          }}
        >
          <BackgroundLayer background={doc.style.background} width={composition.compW} height={composition.compH} />
          <canvas
            ref={canvasRef}
            data-testid="composition"
            role="img"
            aria-label="Screenshot composition"
            className="relative block"
            style={{ width: composition.compW, height: composition.compH }}
          />
          {tool === "select"
            ? CANVAS_HANDLES.map((handle) => (
                <button
                  key={handle}
                  type="button"
                  aria-label={`Resize canvas ${handle}`}
                  className="absolute z-10 h-2.5 w-2.5 rounded-[2px] border border-white bg-accent"
                  style={{
                    ...canvasHandleStyle(handle, composition.compW, composition.compH),
                    transform: `translate(-50%, -50%) scale(${1 / Math.max(scale, 0.05)})`,
                  }}
                  onPointerDown={(event) => onCanvasResize(event, handle)}
                />
              ))
            : null}
          {textStyle ? (
            <textarea
              ref={textRef}
              value={session?.text ?? ""}
              aria-label="Annotation text"
              className="absolute m-0 min-w-16 resize-none border border-dashed border-accent bg-white/80 p-0 leading-[1.25] outline-none"
              style={{
                left: textStyle.left,
                top: textStyle.top,
                fontSize: textStyle.fontSize,
                color: textStyle.color,
                fontFamily: "inherit",
                width: Math.max(80, (session?.text.length ?? 1) * textStyle.fontSize * 0.62),
                height: Math.max(textStyle.fontSize * 1.3, (session?.text.split("\n").length ?? 1) * textStyle.fontSize * 1.25 + 4),
              }}
              onChange={(event) => {
                const text = event.target.value;
                const current = sessionRef.current;
                if (!current) return;
                const next = { ...current, text };
                sessionRef.current = next;
                setSession(next);
                if (current.id) {
                  onLive({
                    ...docRef.current,
                    annotations: docRef.current.annotations.map((annotation) =>
                      annotation.id === current.id && annotation.type === "text" ? { ...annotation, text } : annotation,
                    ),
                  });
                }
              }}
              onKeyDown={(event) => {
                if (event.key === "Escape") {
                  event.preventDefault();
                  cancelText();
                } else if (event.key === "Enter" && !event.shiftKey) {
                  event.preventDefault();
                  commitText();
                }
              }}
              onBlur={() => {
                if (performance.now() - textOpenedAt.current < 300) {
                  requestAnimationFrame(() => textRef.current?.focus());
                  return;
                }
                commitText();
              }}
            />
          ) : null}
        </div>
      ) : null}

      {doc.image ? (
        <>
          <div className="absolute bottom-3 left-3 z-10 flex items-center rounded-full border border-line bg-panel px-1 py-1 shadow-sm">
            <button type="button" className="h-7 w-7 rounded-full text-[14px] text-ink hover:bg-surface" aria-label="Zoom out" onClick={() => zoomAt(1 / 1.1, size.w / 2, size.h / 2)}>
              −
            </button>
            <span aria-live="polite" className="min-w-12 px-1 text-center text-[12px] text-ink tabular-nums">
              {Math.round(scale * 100)}%
            </span>
            <button type="button" className="h-7 w-7 rounded-full text-[14px] text-ink hover:bg-surface" aria-label="Zoom in" onClick={() => zoomAt(1.1, size.w / 2, size.h / 2)}>
              +
            </button>
            <span className="mx-1 h-4 w-px bg-line" />
            <button type="button" className="h-7 rounded-full px-2 text-[12px] text-ink hover:bg-surface" onClick={fit}>
              Fit
            </button>
            <button type="button" className="h-7 rounded-full px-2 text-[12px] text-ink hover:bg-surface" onClick={actualSize}>
              100%
            </button>
          </div>
          <div
            role="toolbar"
            aria-label="Annotation tools"
            className="absolute bottom-3 left-1/2 z-10 flex max-w-[calc(100%-8rem)] -translate-x-1/2 items-center gap-0.5 overflow-x-auto rounded-full border border-black/10 bg-white px-1.5 py-1 shadow-[0_8px_24px_rgba(0,0,0,0.12)]"
          >
            {DOCK_TOOLS.map((item, index) => (
              <span key={item} className="contents">
                {index === 4 || index === 7 || index === 9 || index === 11 ? <span className="mx-1 h-4 w-px shrink-0 bg-line" /> : null}
                <button
                  type="button"
                  aria-label={item}
                  aria-pressed={tool === item}
                  title={item}
                  className={`flex h-8 w-8 shrink-0 items-center justify-center rounded-full text-ink hover:bg-surface ${tool === item ? "bg-[#3478F6]/12 text-accent" : ""}`}
                  onClick={() => onTool(item)}
                >
                  <ToolIcon tool={item} />
                </button>
              </span>
            ))}
          </div>
        </>
      ) : null}
    </div>
  );
}

const CANVAS_HANDLES = ["nw", "n", "ne", "e", "se", "s", "sw", "w"] as const;
type CanvasHandle = (typeof CANVAS_HANDLES)[number];

function canvasHandleStyle(handle: CanvasHandle, width: number, height: number): React.CSSProperties {
  const x = handle.includes("w") ? 0 : handle.includes("e") ? width : width / 2;
  const y = handle.includes("n") ? 0 : handle.includes("s") ? height : height / 2;
  const cursor =
    handle === "n" || handle === "s"
      ? "ns-resize"
      : handle === "e" || handle === "w"
        ? "ew-resize"
        : handle === "nw" || handle === "se"
          ? "nwse-resize"
          : "nesw-resize";
  return { left: x, top: y, cursor };
}

function ratioFor(canvas: Doc["style"]["canvas"]) {
  if (canvas === "1:1") return 1;
  if (canvas === "4:3") return 4 / 3;
  if (canvas === "3:2") return 3 / 2;
  if (canvas === "16:9") return 16 / 9;
  return null;
}

function BackgroundLayer({ background, width, height }: { background: Background; width: number; height: number }) {
  const ref = useRef<HTMLCanvasElement>(null);
  useEffect(() => {
    const canvas = ref.current;
    if (!canvas) return;
    const longest = Math.max(width, height, 1);
    const factor = Math.min(1, 1400 / longest);
    canvas.width = Math.max(1, Math.round(width * factor));
    canvas.height = Math.max(1, Math.round(height * factor));
    const ctx = canvas.getContext("2d");
    if (!ctx) return;
    ctx.setTransform(factor, 0, 0, factor, 0, 0);
    paintBackground(ctx, background, width, height);
  }, [background, width, height]);
  return <canvas ref={ref} aria-hidden className="pointer-events-none absolute inset-0 h-full w-full" />;
}

const DOCK_TOOLS: Tool[] = [
  "select",
  "rect",
  "rect-fill",
  "circle",
  "line",
  "arrow",
  "draw",
  "text",
  "marker",
  "pixelate",
  "blur",
  "crop",
];

function computeScale(view: View, size: { w: number; h: number }, compW: number, compH: number) {
  if (size.w < 8 || size.h < 8) return 1;
  const fit = Math.min((size.w - 28) / compW, (size.h - 88) / compH);
  const fitted = clampZoom(fit);
  return view.mode === "fit" ? fitted : view.zoom;
}

function computePan(view: View, size: { w: number; h: number }, compW: number, compH: number, scale: number) {
  if (view.mode === "fit") {
    return { x: (size.w - compW * scale) / 2, y: (size.h - compH * scale) / 2 };
  }
  return { x: view.panX, y: view.panY };
}

function clampZoom(value: number) {
  if (!Number.isFinite(value)) return 1;
  return Math.min(6, Math.max(0.08, value));
}

function createDraft(tool: Tool, point: { x: number; y: number }, brush: Brush): Annotation | null {
  const id = crypto.randomUUID();
  const base = { id, color: brush.color, strokeWidth: brush.strokeWidth };
  if (tool === "line" || tool === "arrow") {
    return { ...base, type: tool, x: point.x, y: point.y, x2: point.x, y2: point.y };
  }
  if (tool === "draw") return { ...base, type: "draw", points: [point] };
  if (tool === "rect" || tool === "rect-fill" || tool === "circle" || tool === "pixelate" || tool === "blur") {
    return {
      ...base,
      type: tool,
      x: point.x,
      y: point.y,
      w: 0,
      h: 0,
      amount: tool === "blur" ? brush.blur : brush.pixelSize,
    };
  }
  return null;
}

function continueDraft(
  annotation: Annotation,
  start: { x: number; y: number },
  point: { x: number; y: number },
  shift: boolean,
): Annotation {
  if (annotation.type === "line" || annotation.type === "arrow") {
    const end = constrainLine(start.x, start.y, point.x, point.y, shift);
    return { ...annotation, x2: end.x2, y2: end.y2 };
  }
  if (annotation.type === "draw") {
    const last = annotation.points[annotation.points.length - 1];
    if (last && Math.hypot(point.x - last.x, point.y - last.y) < 1.5) return annotation;
    return { ...annotation, points: [...annotation.points, point] };
  }
  if (
    annotation.type === "rect" ||
    annotation.type === "rect-fill" ||
    annotation.type === "circle" ||
    annotation.type === "pixelate" ||
    annotation.type === "blur"
  ) {
    const box = constrainBox(point.x - start.x, point.y - start.y, shift);
    return { ...annotation, w: box.w, h: box.h };
  }
  return annotation;
}

function isTyping(target: EventTarget | null) {
  return target instanceof HTMLElement && (target.tagName === "INPUT" || target.tagName === "TEXTAREA" || target.isContentEditable);
}

function isUiTarget(target: EventTarget | null) {
  return target instanceof HTMLElement && Boolean(target.closest("textarea, input, button, a"));
}
