import type { ReactNode, SVGProps } from "react";
import type { Tool } from "@/lib/types";

type IconProps = SVGProps<SVGSVGElement> & { size?: number };

function Svg({ size = 16, children, ...props }: IconProps & { children: ReactNode }) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.7"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
      {...props}
    >
      {children}
    </svg>
  );
}

export function ShotliMark({ size = 20 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 32 32" aria-hidden="true">
      <rect width="32" height="32" rx="8" fill="#3478F6" />
      <rect x="6.5" y="8" width="19" height="15" rx="2.5" fill="white" />
      <circle cx="10.2" cy="11.6" r="1" fill="#3478F6" />
      <circle cx="13.2" cy="11.6" r="1" fill="#B9CCF8" />
      <circle cx="16.2" cy="11.6" r="1" fill="#B9CCF8" />
      <rect x="9.2" y="14.6" width="13.4" height="1.4" rx="0.7" fill="#D6E2FC" />
      <rect x="9.2" y="17.4" width="8.4" height="1.4" rx="0.7" fill="#D6E2FC" />
    </svg>
  );
}

export function IconCrop(props: IconProps) {
  return (
    <Svg {...props}>
      <path d="M7 3v14a2 2 0 0 0 2 2h14" />
      <path d="M3 7h14a2 2 0 0 1 2 2v14" />
    </Svg>
  );
}

export function IconUndo(props: IconProps) {
  return (
    <Svg {...props}>
      <path d="M9 14 4 9l5-5" />
      <path d="M20 20a8 8 0 0 0-8-8H4" />
    </Svg>
  );
}

export function IconRedo(props: IconProps) {
  return (
    <Svg {...props}>
      <path d="m15 14 5-5-5-5" />
      <path d="M4 20a8 8 0 0 1 8-8h8" />
    </Svg>
  );
}

export function IconDownload(props: IconProps) {
  return (
    <Svg {...props}>
      <path d="M12 4v10" />
      <path d="m8 10 4 4 4-4" />
      <path d="M5 19h14" />
    </Svg>
  );
}

export function IconSidebar(props: IconProps) {
  return (
    <Svg {...props}>
      <rect x="4" y="4" width="16" height="16" rx="2" />
      <path d="M15 4v16" />
    </Svg>
  );
}

export function IconImport(props: IconProps) {
  return (
    <Svg {...props}>
      <path d="M12 16V5" />
      <path d="m8 9 4-4 4 4" />
      <path d="M5 19h14" />
    </Svg>
  );
}

export function IconChevron({ open, ...props }: IconProps & { open: boolean }) {
  return (
    <Svg {...props} className={open ? "rotate-180" : undefined}>
      <path d="m6 9 6 6 6-6" />
    </Svg>
  );
}

export function ToolIcon({ tool, ...props }: IconProps & { tool: Tool }) {
  switch (tool) {
    case "select":
      return (
        <Svg {...props}>
          <path d="m5 4 6.5 15 1.8-6.2L19 11z" />
        </Svg>
      );
    case "crop":
      return <IconCrop {...props} />;
    case "rect":
      return (
        <Svg {...props}>
          <rect x="5" y="6" width="14" height="12" rx="1.5" />
        </Svg>
      );
    case "rect-fill":
      return (
        <Svg {...props}>
          <rect x="5" y="6" width="14" height="12" rx="1.5" fill="currentColor" stroke="none" />
        </Svg>
      );
    case "circle":
      return (
        <Svg {...props}>
          <circle cx="12" cy="12" r="7" />
        </Svg>
      );
    case "line":
      return (
        <Svg {...props}>
          <path d="M5 18 19 6" />
        </Svg>
      );
    case "arrow":
      return (
        <Svg {...props}>
          <path d="M5 18 18 6" />
          <path d="M10 6h8v8" />
        </Svg>
      );
    case "draw":
      return (
        <Svg {...props}>
          <path d="M4 16c2-4 3-6 6-6s2 3 4 3 4-5 6-7" />
        </Svg>
      );
    case "text":
      return (
        <Svg {...props}>
          <path d="M6 6h12" />
          <path d="M12 6v12" />
          <path d="M9 18h6" />
        </Svg>
      );
    case "marker":
      return (
        <Svg {...props}>
          <circle cx="12" cy="12" r="7" />
          <path d="M12 9v6" />
          <path d="M10.2 10.2h2.4" />
        </Svg>
      );
    case "pixelate":
      return (
        <Svg {...props}>
          <rect x="4" y="4" width="6" height="6" fill="currentColor" stroke="none" />
          <rect x="14" y="4" width="6" height="6" />
          <rect x="4" y="14" width="6" height="6" />
          <rect x="14" y="14" width="6" height="6" fill="currentColor" stroke="none" />
        </Svg>
      );
    case "blur":
      return (
        <Svg {...props}>
          <circle cx="12" cy="12" r="3" />
          <circle cx="12" cy="12" r="6.5" opacity="0.7" />
          <circle cx="12" cy="12" r="9" opacity="0.4" />
        </Svg>
      );
  }
}
