export type ShotliFile = {
  name: string;
  type: string;
  bytes: ArrayBuffer;
};

export type ShotliDesktop = {
  isDesktop: true;
  platform: string;
  savePng: (bytes: ArrayBuffer, filename: string) => Promise<{ saved: boolean }>;
  onOpenFiles: (callback: (files: ShotliFile[]) => void) => () => void;
  onExport: (callback: () => void) => () => void;
};

declare global {
  interface Window {
    shotli?: ShotliDesktop;
  }
}

export function desktopApi() {
  if (typeof window === "undefined") return null;
  return window.shotli ?? null;
}
