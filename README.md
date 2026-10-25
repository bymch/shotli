# Shotli

Make every screenshot look better.

Hi, I'm Michael. Shotli is my first open source project.

I take a lot of screenshots, and I kept wanting the same few things before I shared one: a calmer background, a frame, a shadow, a mark or two, then a PNG. Shotli is the Mac app I wanted for that. You download it, open it, and the picture stays on your Mac.

This is the first project I have put out in public, so the rough edges are mine. Issues and pull requests are welcome.

## Download

**[Download Shotli for Mac](https://github.com/bymch/shotli/releases/latest/download/Shotli.dmg)**

Requires macOS 12 or newer. One download works on Apple silicon and Intel.

1. Open `Shotli.dmg`.
2. Drag **Shotli** into your Applications folder.
3. Launch Shotli.

The first time you open it, macOS may say the developer cannot be verified. Control-click Shotli, choose **Open**, then choose **Open** again. I don't have an Apple developer account yet, so the app isn't notarized.

You can also open a PNG, JPEG, or WebP from Finder with Shotli, or drop it on the window.

## What you can do

- Import a PNG, JPEG, or WebP file, drop it on the window, or paste an image.
- **Use a sample** loads a local demo screenshot so you can try the tools immediately.
- Presets set the background, padding, corner radius, shadow and frame together.
- Draw with the tools in the properties sidebar. Select an object to move, resize or delete it.
- Pixelate and blur paint into the exported image. They are not a separate overlay.
- Crop from the toolbar, then drag on the screenshot. Reset crop is in Layout.
- **Export PNG** asks where to save. The file is the composition only: background, frame, shadow, annotations and redactions. The editor grid is not included.

Images larger than 25 MB are refused. Images longer than 4096px on the long edge are scaled down before editing, and export uses that scaled size.

### Shortcuts

| Action | Shortcut |
| --- | --- |
| Undo | ⌘ Z |
| Redo | ⌘ Shift Z, or ⌘ Y |
| Export | ⌘ E or ⌘ S |
| Import | ⌘ O |
| Fit | ⌘ 0 |
| Zoom | ⌘ + or −, or pinch |
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

Open [http://localhost:3000](http://localhost:3000) while working on the editor.

To open the desktop shell locally:

```bash
npm run desktop:export
npm run desktop
```

A Mac disk image is built on GitHub when a release runs. See `.github/workflows/mac.yml`.

```bash
npm run lint
npm run typecheck
npm run build
```

## Stack

The window is an Electron app. The editor is Next.js, React, TypeScript and Tailwind CSS, drawn with the browser Canvas 2D API. There is no account, database or API key.

## Licence

[MIT](LICENSE)
