# Shotli

Make every screenshot look better.

Hi, I'm Michael. Shotli is my first open source project.

I take a lot of screenshots, and I kept wanting the same few things before I shared one: a calmer background, a frame, a shadow, a mark or two, then a PNG. The tools I already had were either a full design app or a site that uploaded the picture. I built Shotli so that work can happen in the browser, on the machine the screenshot is already on.

It is a small editor on purpose. Import an image, place it on a canvas, adjust the background, padding, frame and shadow, annotate or redact it, and export a PNG. Nothing is uploaded. There is no account.

This is the first project I have put out in public, so the rough edges are mine. Issues and pull requests are welcome. If something feels confusing, that is useful to hear.

## What you can do

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

## Stack

Next.js, React, TypeScript and Tailwind CSS. The canvas is drawn with the browser Canvas 2D API. There is no database or API key.

## Licence

[MIT](LICENSE)
