# Shotli

Make every screenshot look better.

Hi, I'm Michael. Shotli is my first open source project.

I take a lot of screenshots, and I kept wanting the same few things before I shared one: a calmer background, a frame, a shadow, a mark or two, then a PNG. Shotli is the Mac app I wanted for that. You download it, open it, and the picture stays on your Mac.

This is the first project I have put out in public, so the rough edges are mine. Issues and pull requests are welcome.

## Download

**[Download Shotli for Mac](https://github.com/bymch/shotli/releases/latest/download/Shotli.dmg)**

Requires macOS 12 or newer. One download works on Apple silicon and Intel. The app is native Swift, so the disk image is the app itself rather than a bundled browser.

1. Open `Shotli.dmg`.
2. Drag **Shotli** onto the Applications folder in that window.
3. Open Shotli from Applications.

Shotli stays in the menu bar. Click the viewfinder and choose **Capture Full Screen**, **Capture Window**, or **Capture Area**. The picture opens in Shotli. Closing the window leaves the menu bar item in place. Quit is in that menu.

The same three captures have keyboard shortcuts. Change them in Settings. The defaults are ⌃⌥⌘1 for the full screen, ⌃⌥⌘2 for a window, and ⌃⌥⌘3 for an area. They work while another app is in front. Click a shortcut in Settings and press the keys you want. Delete clears it.

The first time you capture, macOS asks for Screen & System Audio Recording. That dialog is Apple's, and it mentions audio even though Shotli never records any. Its Open System Settings button often does nothing. Shotli opens the Screen Recording pane itself. Turn Shotli on, quit the app, and open it again. If the switch does nothing, select Shotli, click the minus button, and try the capture once more. Shotli has to be the copy in Applications. A copy opened from the disk image cannot keep the permission. Allow Screen Recording once for Shotli 0.2.38 or newer. Later updates keep it. Dropping, pasting, or opening a picture does not ask.

The first time you open it, macOS may say the developer cannot be verified. Control-click Shotli, choose **Open**, then choose **Open** again. I don't have an Apple developer account yet, so the app isn't notarized.

You can also open a PNG, JPEG, or WebP from Finder with Shotli, or drop it on the window. The home screen lists recent pictures from the Desktop, Pictures, the Screenshots folder, and `Pictures/Shotli`. Captures from the menu bar are saved into `Pictures/Shotli`. If you just want to try the tools, open **Sample**.

## Updates

From 0.2.2 onwards, **Check for Updates…** downloads the new version and replaces the Shotli you already have. It is in the Shotli menu, next to About, and in the menu bar. You don't delete the old app or drag a new disk image over it. Shotli quits, puts the new copy in place, and opens again.

0.2.2 is the last version you install by hand from the disk image. The copy you have before that doesn't know how to replace itself.

macOS may ask you to Control-click and Open again after an update, because the app still isn't notarized. If Shotli is running from the disk image rather than Applications, the update is installed into Applications.

## What you can do

- Browse Recent, Screenshots, Desktop, Pictures, and Shotli from the library on the left. The back button at the top left, or the View menu (⌘L), comes back to that list.
- Capture the full screen, one window, or an area from the menu bar, or with the shortcuts in Settings. The area selector dims the screen, shows the size as you drag, and lets you move or resize the box before Return captures it. Escape cancels.
- Import a PNG, JPEG, or WebP file, drop it on the window, or paste an image.
- **Use a sample** loads a local demo screenshot so you can try the tools immediately.
- Presets set the background, padding, corner radius, shadow and frame together.
- The library shows each picture as a glass document. The thumbnail sits behind the page, and the folded corner is part of that page. The number of columns follows the window. Search, sort, and the grid or list control are in the toolbar. Right-click a card to rename, duplicate, reveal it in Finder, or delete it. New project saves a blank canvas in Pictures/Shotli and opens it.
- Backgrounds stay at the top of the mockup panel. Each row shows three, and the headings collapse. More opens the rest of that set over the picture. The plus on a linear gradient applies one of its colours as a flat background.
- The editor is three columns on a cool workspace. The toolbar, side panels, and overlays are translucent glass. The picture in the middle is not. The left side is the mockup: card style, corners, shadow, light, and hide mockup. Zoom and layout presets are on the right. Drawing tools are along the top. The back arrow returns to your screenshots.
- Templates, at the top left, opens a gallery. Each one sets a background, a position, and an angle. Product shots use studio sweeps. Abstract colour uses bloom, tide, citrus, and the rest. Angled ones lean the screenshot so the background stays in frame.
- Fit keeps the whole screenshot in the window. Zooming out makes the picture smaller, and the background colour still fills the stage. Canvas width and height are in the panel.
- Pixelate and blur paint into the exported image. They are not a separate overlay.
- Crop from the toolbar, then drag on the screenshot. Reset crop is in Layout.
- **Export PNG** asks where to save. The file is the composition only: background, frame, shadow, annotations and redactions. The glass toolbar and panels are not included.
- **Motion**, under the picture, opens Motion Studio. Float, Perspective, Focus, Drift, Orbit, and Reveal move that screenshot on its background. Duration, speed, and loop sit in the inspector. Adjust holds movement, rotation, zoom, perspective, shadow, and background travel. Export video writes a 1080p H.264 MP4, and an optional music file is trimmed into it. The still PNG export stays where it was.

Images larger than 25 MB are refused. Images longer than 4096px on the long edge are scaled down before editing, and export uses that scaled size.

### Shortcuts

| Action | Shortcut |
| --- | --- |
| Undo | ⌘ Z |
| Redo | ⌘ Shift Z, or ⌘ Y |
| Export | ⌘ E or ⌘ S |
| Import | ⌘ O |
| Library | ⌘ L |
| Paste image | ⌘ V |
| Fit | ⌘ 0 |
| Zoom | Pinch, or ⌘ scroll |
| Pan | Space-drag or middle-drag, once the picture is larger than the window |
| Delete | Delete or Backspace |
| Tools | V select, R rectangle, F fill, C circle, L line, A arrow, D draw, T text, N number, P pixelate, B blur, K crop |

Hold Shift while drawing a line, arrow, rectangle or circle to constrain it.

## Develop

The Mac app is in `macos/Sources/Shotli`. On a Mac with Xcode:

```bash
bash scripts/build-mac.sh
open dist/Shotli.dmg
```

That compiles a universal binary, signs it just enough for Apple silicon to launch it, and builds the disk image. There is no Apple notarization step.

The browser editor is still in this repo. It is useful for trying the layout without Xcode:

```bash
npm install
npm run dev
```

Open [http://localhost:3000](http://localhost:3000). The downloadable app is the Swift one.

```bash
npm run lint
npm run typecheck
npm run build
```

A Mac disk image is built on GitHub when a release runs. See `.github/workflows/mac.yml`.

## Stack

The Mac app is Swift and SwiftUI, drawn with Core Graphics. The browser editor is Next.js, React, TypeScript and Tailwind CSS. There is no account, database or API key.

## Licence

[MIT](LICENSE)
