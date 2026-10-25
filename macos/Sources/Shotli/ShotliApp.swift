import AppKit
import SwiftUI

@main
struct ShotliApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = EditorModel.shared

    var body: some Scene {
        WindowGroup {
            EditorView(model: model)
                .frame(minWidth: 980, minHeight: 680)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            ShotliCommands(model: model)
        }
    }
}

struct ShotliCommands: Commands {
    @ObservedObject var model: EditorModel

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About Shotli") {
                NSApp.orderFrontStandardAboutPanel(options: [
                    .applicationName: "Shotli",
                    .applicationVersion: "0.2.0",
                    .credits: NSAttributedString(
                        string: "Make every screenshot look better.\n© 2026 Michael",
                        attributes: [
                            .font: NSFont.systemFont(ofSize: 11),
                            .foregroundColor: NSColor.secondaryLabelColor,
                        ]
                    ),
                ])
            }
        }
        CommandGroup(replacing: .newItem) {
            Button("Open…") { model.openPanel() }
                .keyboardShortcut("o", modifiers: .command)
            Button("Export PNG") { model.exportPNG() }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(model.picture == nil)
            Divider()
            Button("Use Sample Screenshot") { model.useSample() }
        }
        CommandGroup(replacing: .undoRedo) {
            Button("Undo") { model.undo() }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(!model.canUndo)
            Button("Redo") { model.redo() }
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(!model.canRedo)
        }
        CommandGroup(after: .toolbar) {
            Button("Fit to Window") { model.fit() }
                .keyboardShortcut("0", modifiers: .command)
                .disabled(model.picture == nil)
        }
        CommandGroup(replacing: .help) {
            Button("Keyboard Shortcuts") { showShortcuts() }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var monitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.modifierFlags.contains(.command) else { return event }
            if event.modifierFlags.contains(.shift) || event.modifierFlags.contains(.option) { return event }
            if NSApp.keyWindow?.firstResponder is NSTextView { return event }
            switch event.charactersIgnoringModifiers?.lowercased() {
            case "e":
                EditorModel.shared.exportPNG()
                return nil
            case "y":
                EditorModel.shared.redo()
                return nil
            case "v":
                guard NSPasteboard.general.canReadObject(forClasses: [NSImage.self], options: nil) else { return event }
                EditorModel.shared.pasteImage()
                return nil
            default:
                return event
            }
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.isFileURL {
            EditorModel.shared.load(url: url)
        }
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        EditorModel.shared.load(url: URL(fileURLWithPath: filename))
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

private func showShortcuts() {
    let alert = NSAlert()
    alert.messageText = "Shortcuts"
    alert.informativeText = """
    Undo ⌘Z
    Redo ⌘⇧Z, or ⌘Y
    Open ⌘O
    Export ⌘S, or ⌘E
    Paste an image ⌘V
    Fit ⌘0
    Delete Backspace

    V select, R rectangle, F fill, C circle, L line, A arrow, D draw, T text, N number, P pixelate, B blur, K crop

    Hold Shift to keep a line or box square. Scroll to pan. Pinch, or hold ⌘ and scroll, to zoom.
    """
    alert.addButton(withTitle: "OK")
    alert.runModal()
}
