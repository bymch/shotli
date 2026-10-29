import AppKit
import SwiftUI

struct ChangelogEntry: Identifiable {
    var version: String
    var notes: [String]
    var id: String { version }
}

enum Changelog {
    static let entries: [ChangelogEntry] = [
        ChangelogEntry(version: "0.2.62", notes: [
            "Phone, tablet, laptop, and watch frames are turned off. The screenshot stays on the card.",
        ]),
        ChangelogEntry(version: "0.2.61", notes: [
            "The device picker floats beside the Mockup selector. Names and pixel sizes follow Apple's specs, checked 28 October 2026.",
        ]),
        ChangelogEntry(version: "0.2.60", notes: [
            "Phone frames have a metal edge, a thin black lip, a camera island, and side buttons. The screenshot still sits in the glass.",
        ]),
        ChangelogEntry(version: "0.2.59", notes: [
            "Devices puts the screenshot inside a phone, tablet, laptop, desktop, or watch. Finishes, export, and Save to Project keep that mockup.",
        ]),
        ChangelogEntry(version: "0.2.58", notes: [
            "A second area capture joins the composition. Return on another grab adds that picture beside the first.",
        ]),
        ChangelogEntry(version: "0.2.57", notes: [
            "The editor title stays on one line, and truncates only when the window is too narrow.",
            "Add screenshot puts more pictures in the same composition. Layout presets follow how many you have.",
        ]),
        ChangelogEntry(version: "0.2.56", notes: [
            "Settings has Appearance: System, Light, or Dark. System follows the Mac, and the choice is remembered.",
            "Dark mode keeps the glass documents, with the picture showing through. Exported images keep their colours.",
        ]),
        ChangelogEntry(version: "0.2.55", notes: [
            "Project cards sit side by side. Opening a project shows the pictures inside it.",
            "Document icons are frosted glass, with the artwork showing through the page.",
            "An empty project can open a screenshot or an image. The original file stays where it is.",
        ]),
        ChangelogEntry(version: "0.2.54", notes: [
            "Save to Project: click anywhere on the project row. The name sits beside the thumbnail, then Shotli confirms Saved.",
            "The empty projects screen keeps Create project in the middle. Backspace works in the project name.",
        ]),
        ChangelogEntry(version: "0.2.53", notes: [
            "Opening a project with more than one composition shows each saved picture. Click one to edit it.",
        ]),
        ChangelogEntry(version: "0.2.52", notes: [
            "The accent is sky blue. Selected rows and New project use it.",
        ]),
        ChangelogEntry(version: "0.2.51", notes: [
            "A project is a folder. New project asks for a name, then creates it in Application Support.",
            "Save to Project, in the editor next to Export and Copy, keeps the composition and a copy of the screenshot.",
            "The library opens on those folders. Rename, duplicate, and delete act on the folder. The countdown under each card is gone.",
        ]),
        ChangelogEntry(version: "0.2.50", notes: [
            "Zooming out keeps the background colour across the stage. The picture gets smaller, and the gray around it is gone.",
        ]),
        ChangelogEntry(version: "0.2.49", notes: [
            "Projects open as glass document cards. The picture shows through the page, including the folded corner.",
            "New project, duplicate, and reveal in Finder are in the library. Search, sort, and grid or list stay.",
        ]),
        ChangelogEntry(version: "0.2.48", notes: [
            "Motion Studio adds Orbit and Reveal, a timeline, and speed, zoom, perspective, shadow, and background controls.",
            "Optional music plays in the preview and is mixed into the 1080p MP4. PNG export is unchanged.",
        ]),
        ChangelogEntry(version: "0.2.47", notes: [
            "Motion Studio loops the screenshot: Float, Perspective, Focus, and Drift. Export video writes a 1080p MP4. PNG export is unchanged.",
        ]),
        ChangelogEntry(version: "0.2.46", notes: [
            "The background list no longer has a search field. Categories, three thumbnails, and More stay.",
            "Open a screenshot stays next to the library title. The extra one at the bottom of the sidebar is gone.",
        ]),
        ChangelogEntry(version: "0.2.45", notes: [
            "The editor chrome is floating glass: toolbar, side panels, and the panels that open over the picture. The exported image is unchanged.",
        ]),
        ChangelogEntry(version: "0.2.44", notes: [
            "Renaming a screenshot keeps its category and the words Shotli already read.",
        ]),
        ChangelogEntry(version: "0.2.43", notes: [
            "The library uses larger screenshots, and the grid follows the window width.",
            "Sort by most recent, oldest, or name. Rename, reveal, and delete are in the thumbnail menu.",
            "Background categories collapse. Search finds one by name. More opens the rest, and a gradient's plus uses its colours as a flat background.",
        ]),
        ChangelogEntry(version: "0.2.42", notes: [
            "Background names stay fully visible, and each swatch has a plus that opens the rest of that set.",
            "Padding, zoom, tilt, and layout presets are grouped more clearly.",
        ]),
        ChangelogEntry(version: "0.2.41", notes: [
            "Each background row shows three. More opens the rest over the picture.",
        ]),
        ChangelogEntry(version: "0.2.40", notes: [
            "More backgrounds: gradients, glass waves, cosmic colour, soft fields, landscapes, abstract shapes, and earth tones. They are at the top of the mockup panel.",
        ]),
        ChangelogEntry(version: "0.2.39", notes: [
            "Set keyboard shortcuts for full screen, window, and area capture. They work while another app is in front.",
        ]),
        ChangelogEntry(version: "0.2.38", notes: [
            "Screen Recording stays allowed after an update. This version asks one last time.",
        ]),
        ChangelogEntry(version: "0.2.37", notes: [
            "Settings is at the bottom of the library. Allow Screen Recording, Desktop, Documents, and Downloads from there.",
            "Screenshots are sorted into Code, Websites, Documents, Conversations, and Other. Apple Intelligence does this when it is on. Otherwise Shotli reads the text on this Mac.",
            "Search finds words inside a screenshot, not only its name.",
            "Right-click a thumbnail and choose File as to put it in a category yourself.",
            "A click anywhere on a library row opens that folder.",
        ]),
        ChangelogEntry(version: "0.2.36", notes: [
            "Each release in the changelog sits on its own card, so the notes are easier to read.",
        ]),
        ChangelogEntry(version: "0.2.35", notes: [
            "Changelog is in the Shotli menu.",
        ]),
        ChangelogEntry(version: "0.2.34", notes: [
            "Drag the finished picture from the editor into another app.",
            "Drag a thumbnail in the library to share the original file.",
        ]),
        ChangelogEntry(version: "0.2.33", notes: [
            "Select one screenshot, several, or all of them in the library.",
            "Delete asks first, then moves the selected files to the Trash.",
        ]),
        ChangelogEntry(version: "0.2.32", notes: [
            "Start Over asks before it clears the screenshot and returns to the library.",
        ]),
        ChangelogEntry(version: "0.2.31", notes: [
            "Capture Area opens the picture in the editor when you press Return.",
        ]),
        ChangelogEntry(version: "0.2.30", notes: [
            "The library fills the space under the window buttons.",
        ]),
        ChangelogEntry(version: "0.2.29", notes: [
            "Templates and Export stay hidden while you are browsing screenshots.",
        ]),
        ChangelogEntry(version: "0.2.28", notes: [
            "Shotli opens Screen Recording settings itself.",
            "Capture Area shows the size and lets you move or resize the box. Return captures it, and Escape cancels.",
        ]),
        ChangelogEntry(version: "0.2.27", notes: [
            "Copy the finished picture to the clipboard.",
        ]),
        ChangelogEntry(version: "0.2.26", notes: [
            "Sharp, Curved, and Round change the corners of the picture.",
        ]),
        ChangelogEntry(version: "0.2.25", notes: [
            "The colour control is named Palette.",
        ]),
        ChangelogEntry(version: "0.2.24", notes: [
            "Palette suggests backgrounds from the colours in the screenshot.",
        ]),
        ChangelogEntry(version: "0.2.23", notes: [
            "The top bar lines up with the editor, and its buttons receive clicks.",
        ]),
        ChangelogEntry(version: "0.2.22", notes: [
            "Each template card is a different placement of the screenshot.",
        ]),
        ChangelogEntry(version: "Earlier", notes: [
            "The editor is three columns: the mockup, the picture, and layout.",
            "Backgrounds include solid colours, gradients, and scenes. Frames, shadows, and drawing tools are on the picture.",
            "Check for Updates downloads the new version and replaces this copy.",
            "Capture from the menu bar: full screen, a window, or an area.",
            "The library lists Recent, Screenshots, Desktop, Pictures, and Shotli.",
        ]),
    ]

    private static var window: NSWindow?

    static func show() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        if let window {
            window.makeKeyAndOrderFront(nil)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Changelog"
        window.contentView = NSHostingView(rootView: ChangelogView())
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 360, height: 320)
        window.center()
        self.window = window
        window.makeKeyAndOrderFront(nil)
    }
}

private struct ChangelogView: View {
    private var ink: Color { ShotliGlass.ink(colorScheme) }
    private let accent = Color(nsColor: NSColor(hex: "#3478F6")!)
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(Changelog.entries.enumerated()), id: \.element.id) { index, entry in
                    card(entry, current: index == 0)
                }
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ShotliGlass.page(colorScheme))
        .shotliAppearance()
        .onChange(of: colorScheme) { _ in
            ShotliSettings.shared.appearance.apply()
        }
    }

    private func card(_ entry: ChangelogEntry, current: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(entry.version)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ink)
                if current {
                    Text("This version")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(accent.opacity(0.12)))
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                ForEach(entry.notes, id: \.self) { note in
                    noteRow(note, marked: entry.notes.count > 1)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(ShotliGlass.surface(colorScheme)))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(current ? ShotliGlass.line(colorScheme) : ShotliGlass.hairline(colorScheme), lineWidth: 1))
    }

    private func noteRow(_ note: String, marked: Bool) -> some View {
        HStack(alignment: .top, spacing: 8) {
            if marked {
                Circle()
                    .fill(ink.opacity(0.45))
                    .frame(width: 5, height: 5)
                    .padding(.top, 6)
            }
            Text(note)
                .font(.system(size: 13))
                .foregroundColor(ink.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
