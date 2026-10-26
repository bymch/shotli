"use client";

import { useRef, useState } from "react";

export type LibrarySourceId = "recent" | "sample";

export type RecentShot = {
  id: string;
  name: string;
  file: File;
  previewUrl: string;
  added: number;
};

const SOURCES: { id: LibrarySourceId; title: string; detail: string; symbol: "clock" | "spark" }[] = [
  { id: "recent", title: "Recent", detail: "This session", symbol: "clock" },
  { id: "sample", title: "Sample", detail: "A picture to try the tools on", symbol: "spark" },
];

export function LibraryHome({
  source,
  recents,
  fileDrag,
  onSource,
  onOpen,
  onOpenRecent,
  onSample,
}: {
  source: LibrarySourceId;
  recents: RecentShot[];
  fileDrag: boolean;
  onSource: (source: LibrarySourceId) => void;
  onOpen: () => void;
  onOpenRecent: (shot: RecentShot) => void;
  onSample: () => void;
}) {
  const [query, setQuery] = useState("");
  const [highlight, setHighlight] = useState(source);
  const [shown, setShown] = useState(source);
  const [visible, setVisible] = useState(true);
  const swap = useRef<number | null>(null);
  const selected = SOURCES.find((item) => item.id === shown) ?? SOURCES[0];
  const highlightIndex = Math.max(0, SOURCES.findIndex((item) => item.id === highlight));
  const needle = query.trim().toLowerCase();
  const filtered = needle ? recents.filter((shot) => shot.name.toLowerCase().includes(needle)) : recents;

  function choose(next: LibrarySourceId) {
    if (next === highlight) return;
    setHighlight(next);
    if (swap.current) window.clearTimeout(swap.current);
    setVisible(false);
    swap.current = window.setTimeout(() => {
      setShown(next);
      onSource(next);
      setVisible(true);
      swap.current = null;
    }, 140);
  }

  return (
    <div className="flex min-h-0 flex-1 flex-col min-[760px]:flex-row">
      <aside className="flex shrink-0 gap-1 overflow-x-auto border-b border-line bg-white px-2 py-2 min-[760px]:w-[220px] min-[760px]:flex-col min-[760px]:overflow-visible min-[760px]:border-r min-[760px]:border-b-0 min-[760px]:px-0 min-[760px]:py-0">
        <div className="hidden px-3.5 pt-4 pb-1.5 text-[11px] font-semibold text-muted min-[760px]:block">Library</div>
        <div className="relative flex gap-1 min-[760px]:mx-2 min-[760px]:flex-col min-[760px]:gap-0.5">
          <div
            aria-hidden
            className="pointer-events-none absolute top-0 hidden h-8 rounded-md bg-accent transition-transform duration-300 ease-[cubic-bezier(0.22,1,0.36,1)] min-[760px]:inset-x-0 min-[760px]:block"
            style={{ transform: `translateY(${highlightIndex * 34}px)` }}
          />
          {SOURCES.map((item) => {
            const active = item.id === highlight;
            return (
              <button
                key={item.id}
                type="button"
                className={`relative flex h-8 shrink-0 items-center gap-2 rounded-md px-2.5 text-[13px] transition-colors duration-200 min-[760px]:bg-transparent ${
                  active ? "bg-accent text-white" : "text-ink hover:bg-black/5"
                }`}
                onClick={() => choose(item.id)}
              >
                <SourceIcon name={item.symbol} />
                <span className="flex-1 text-left">{item.title}</span>
                {item.id === "recent" && recents.length > 0 ? (
                  <span className={active ? "text-[11px] text-white/80" : "text-[11px] text-muted"}>{recents.length}</span>
                ) : null}
              </button>
            );
          })}
        </div>
        <div className="hidden flex-1 min-[760px]:block" />
        <button
          type="button"
          className="flex h-8 shrink-0 items-center gap-2 rounded-md px-2.5 text-[12px] text-ink hover:bg-black/5 min-[760px]:m-3.5 min-[760px]:px-0"
          onClick={onOpen}
        >
          <SourceIcon name="folder" />
          Open a screenshot…
        </button>
      </aside>
      <section className="relative min-h-0 flex-1 overflow-auto bg-workspace">
        <div
          className="transition-opacity duration-150"
          style={{ opacity: visible ? 1 : 0 }}
        >
          <div className="flex items-end justify-between gap-4 px-5 pt-4 pb-3">
            <div>
              <h1 className="text-[18px] font-semibold text-ink">{selected.title}</h1>
              <p className="text-[12px] text-muted">{selected.detail}</p>
            </div>
            {shown === "recent" ? (
              <label className="flex h-7 w-44 items-center gap-1.5 rounded-lg border border-black/8 bg-white px-2 text-muted">
                <SearchIcon />
                <input
                  value={query}
                  onChange={(event) => setQuery(event.target.value)}
                  placeholder="Search"
                  className="w-full bg-transparent text-[12px] text-ink outline-none placeholder:text-muted"
                />
              </label>
            ) : null}
          </div>
          {shown === "recent" ? (
            filtered.length === 0 ? (
              <Empty
                title={needle ? `Nothing matches “${query.trim()}”.` : "Nothing in this session yet."}
                body={
                  needle
                    ? "Try another name, or open a screenshot."
                    : "Capture from the menu above, or drop a PNG, JPEG, or WebP onto this window. On the Mac app, Recent also lists screenshots from your Desktop, Pictures, and the Shotli folder."
                }
              />
            ) : (
              <div className="grid grid-cols-[repeat(auto-fill,minmax(168px,1fr))] gap-3.5 px-5 pb-6">
                {filtered.map((shot) => (
                  <button
                    key={shot.id}
                    type="button"
                    className="rounded-xl p-2 text-left transition-colors duration-150 hover:bg-white"
                    onClick={() => onOpenRecent(shot)}
                  >
                    <span className="flex h-32 items-center justify-center overflow-hidden rounded-[10px] border border-black/6 bg-white">
                      {/* eslint-disable-next-line @next/next/no-img-element */}
                      <img src={shot.previewUrl} alt="" className="max-h-full max-w-full object-contain p-2" />
                    </span>
                    <span className="mt-2 block truncate text-[12px] text-ink">{shot.name}</span>
                    <span className="block text-[11px] text-muted">{relativeTime(shot.added)}</span>
                  </button>
                ))}
              </div>
            )
          ) : (
            <div className="grid grid-cols-[repeat(auto-fill,minmax(168px,1fr))] gap-3.5 px-5 pb-6">
              <button type="button" className="rounded-xl p-2 text-left transition-colors duration-150 hover:bg-white" onClick={onSample}>
                <span className="flex h-32 flex-col items-center justify-center gap-2 rounded-[10px] border border-black/6 bg-white text-accent">
                  <SourceIcon name="spark" />
                  <span className="text-[12px] text-ink">Quarterly plan</span>
                </span>
                <span className="mt-2 block truncate text-[12px] text-ink">Sample screenshot</span>
                <span className="block text-[11px] text-muted">Try the tools</span>
              </button>
            </div>
          )}
        </div>
        {fileDrag ? (
          <div className="pointer-events-none absolute inset-3 flex items-center justify-center rounded-xl border border-dashed border-accent bg-white/70 text-[13px] text-ink">
            Drop to import
          </div>
        ) : null}
      </section>
    </div>
  );
}

function Empty({ title, body }: { title: string; body: string }) {
  return (
    <div className="mx-5 rounded-xl border border-black/6 bg-white px-4 py-4">
      <p className="text-[13px] text-muted">{title}</p>
      <p className="mt-1.5 text-[12px] leading-5 text-muted">{body}</p>
    </div>
  );
}

function relativeTime(added: number) {
  const seconds = Math.max(0, Math.round((Date.now() - added) / 1000));
  if (seconds < 45) return "just now";
  const minutes = Math.round(seconds / 60);
  if (minutes < 60) return `${minutes} minute${minutes === 1 ? "" : "s"} ago`;
  const hours = Math.round(minutes / 60);
  return `${hours} hour${hours === 1 ? "" : "s"} ago`;
}

function SearchIcon() {
  return (
    <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden="true">
      <circle cx="11" cy="11" r="6" />
      <path d="M16 16l4 4" strokeLinecap="round" />
    </svg>
  );
}

function SourceIcon({ name }: { name: "clock" | "spark" | "folder" }) {
  if (name === "clock") {
    return (
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" aria-hidden="true">
        <circle cx="12" cy="12" r="8" />
        <path d="M12 8v4.5l3 2" strokeLinecap="round" />
      </svg>
    );
  }
  if (name === "folder") {
    return (
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" aria-hidden="true">
        <path d="M3 7.5h6l2 2H21v8.5a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1z" strokeLinejoin="round" />
      </svg>
    );
  }
  return (
    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" aria-hidden="true">
      <path d="M12 3.5 13.8 8l4.7.4-3.6 3 1.1 4.6L12 13.6 8 16l1.1-4.6-3.6-3L10.2 8z" strokeLinejoin="round" />
    </svg>
  );
}
