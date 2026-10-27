import AppKit
import SwiftUI

struct ChangelogEntry: Identifiable {
    var version: String
    var notes: [String]
    var id: String { version }
}

enum Changelog {
    static let entries: [ChangelogEntry] = [
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
    private let ink = Color(nsColor: NSColor(hex: "#222222")!)
    private let accent = Color(nsColor: NSColor(hex: "#3478F6")!)

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
        .background(Color(nsColor: NSColor(srgbRed: 0.945, green: 0.945, blue: 0.945, alpha: 1)))
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
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.black.opacity(current ? 0.14 : 0.06), lineWidth: 1))
    }

    private func noteRow(_ note: String, marked: Bool) -> some View {
        HStack(alignment: .top, spacing: 8) {
            if marked {
                Circle()
                    .fill(Color.black.opacity(0.28))
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
