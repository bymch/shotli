# Shotli

Make every screenshot look better.

Shotli is a browser-based screenshot editor. Import an image, place it on a canvas, adjust the background, padding, frame and shadow, annotate or redact it, and export a PNG. Processing stays in the browser. Images are not uploaded.

## Develop

Requires Node.js 20 or newer.

```bash
npm install
npm run dev
```

Open [http://localhost:3000](http://localhost:3000).

```bash
npm run lint
npm run typecheck
npm run build
npm start
```

## Use

- Import a PNG, JPEG, or WebP file, drop it on the window, or paste an image.
- **Use a sample** loads a local demo screenshot so you can try the tools immediately.
- Presets set the background, padding, corner radius, shadow and frame together.
- Draw with the tools in the properties sidebar. Select an object to move, resize or delete it.
- Pixelate and blur paint into the exported image. They are not a separate overlay.
- Crop from the toolbar, then drag on the screenshot. Reset crop is in Layout.
- Export PNG downloads the composition only: background, frame, shadow, annotations and redactions. The editor grid is not included.

Images larger than 25 MB are refused. Images longer than 4096px on the long edge are scaled down before editing, and export uses that scaled size.

### Shortcuts

| Action | Shortcut |
| --- | --- |
| Undo | Ctrl/⌘ Z |
| Redo | Ctrl/⌘ Shift Z, or Ctrl/⌘ Y |
| Export | Ctrl/⌘ E or Ctrl/⌘ S |
| Import | Ctrl/⌘ O |
| Fit | Ctrl/⌘ 0 |
| Zoom | Ctrl/⌘ + or −, or pinch/ctrl-scroll |
| Pan | Space-drag, middle-drag, or scroll |
| Delete | Delete or Backspace |
| Tools | V select, R rectangle, F fill, C circle, L line, A arrow, D draw, T text, N number, P pixelate, B blur, K crop |

Hold Shift while drawing a line, arrow, rectangle or circle to constrain it.

## Stack

Next.js, React, TypeScript and Tailwind CSS. The canvas is drawn with the browser Canvas 2D API. There is no account, database or API key.

## Licence

[MIT](LICENSE)
