import AppKit
import SwiftUI

@main
struct ShotliApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = EditorModel.shared

    var body: some Scene {
        WindowGroup {
            EditorView(model: model)
                .frame(minWidth: 1100, minHeight: 720)
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
                let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.2.1"
                let credits = NSMutableAttributedString(
                    string: "Make every screenshot look better.\n© 2026 ",
                    attributes: [
                        .font: NSFont.systemFont(ofSize: 11),
                        .foregroundColor: NSColor.secondaryLabelColor,
                    ]
                )
                credits.append(NSAttributedString(
                    string: "BM.studio",
                    attributes: [
                        .font: NSFont.systemFont(ofSize: 11),
                        .link: URL(string: "https://bm.studio")!,
                        .foregroundColor: NSColor.linkColor,
                    ]
                ))
                NSApp.orderFrontStandardAboutPanel(options: [
                    .applicationName: "Shotli",
                    .applicationVersion: version,
                    .credits: credits,
                ])
            }
            Divider()
            Button("Check for Updates…") { AppUpdate.shared.check(interactive: true) }
            Button("Changelog") { Changelog.show() }
        }
        CommandGroup(replacing: .appSettings) {
            Button("Settings…") { ShotliSettings.shared.requestOpen() }
                .keyboardShortcut(",", modifiers: .command)
        }
        CommandGroup(replacing: .newItem) {
            Button("Capture Full Screen") { ScreenCapture.shared.capture(.full) }
            Button("Capture Window") { ScreenCapture.shared.capture(.window) }
            Button("Capture Area") { ScreenCapture.shared.capture(.area) }
            Divider()
            Button("Open…") { model.openPanel() }
                .keyboardShortcut("o", modifiers: .command)
            Button("Export PNG") { model.exportPNG() }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(model.picture == nil)
            Button("Save to Project…") {
                model.prepareSavePopover()
                model.showSaveProjects = true
            }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(model.picture == nil)
            Button("Copy PNG") { model.copyPNG() }
                .keyboardShortcut("c", modifiers: [.command, .shift])
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
            Button("Library") { model.showLibrary() }
                .keyboardShortcut("l", modifiers: .command)
                .disabled(model.picture == nil)
            Button("Fit to Window") { model.fit() }
                .keyboardShortcut("0", modifiers: .command)
                .disabled(model.picture == nil)
        }
        CommandGroup(replacing: .help) {
            Button("Keyboard Shortcuts") { showShotliShortcuts() }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var monitor: Any?
    private var statusItem: NSStatusItem?
    private var statusMenu: NSMenu?

    override init() {
        super.init()
        if CommandLine.arguments.contains("--verify-projects") {
            let code = ProjectVerify.run()
            fflush(stdout)
            fflush(stderr)
            exit(Int32(code))
        }
        guard CommandLine.arguments.contains("--verify-motion") else { return }
        let code = MotionVerify.run()
        fflush(stdout)
        fflush(stderr)
        exit(Int32(code))
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if CommandLine.arguments.contains("--verify-projects") {
            let code = ProjectVerify.run()
            fflush(stdout)
            fflush(stderr)
            exit(Int32(code))
        }
        if CommandLine.arguments.contains("--verify-motion") {
            let code = MotionVerify.run()
            fflush(stdout)
            fflush(stderr)
            exit(Int32(code))
        }
        NSWindow.allowsAutomaticWindowTabbing = false
        ShotliSettings.shared.appearance.apply()
        ShotShortcuts.shared.install()
        setMenuBarVisible(ShotliSettings.shared.showMenuBar)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            AppUpdate.shared.checkOnLaunch()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            for window in NSApp.windows where window.canBecomeMain {
                window.isReleasedWhenClosed = false
                window.delegate = WindowKeeper.shared
            }
        }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.modifierFlags.contains(.command) else { return event }
            if event.modifierFlags.contains(.shift) || event.modifierFlags.contains(.option) { return event }
            if NSApp.keyWindow?.firstResponder is NSTextView { return event }
            switch event.charactersIgnoringModifiers?.lowercased() {
            case "e":
                EditorModel.shared.exportPNG()
                return nil
            case "c":
                if NSApp.keyWindow?.firstResponder is NSTextField { return event }
                EditorModel.shared.copyPNG()
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

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        ScreenCapture.shared.revealEditor()
        return true
    }

    func setMenuBarVisible(_ visible: Bool) {
        if visible {
            if statusItem == nil { installStatusItem() }
        } else if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
            self.statusMenu = nil
        }
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            let image = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "Shotli")
            image?.isTemplate = true
            image?.size = NSSize(width: 16, height: 16)
            button.image = image
            button.toolTip = "Shotli"
        }
        let menu = NSMenu()
        menu.addItem(menuItem("Capture Full Screen", #selector(captureFull)))
        menu.addItem(menuItem("Capture Window", #selector(captureWindow)))
        menu.addItem(menuItem("Capture Area", #selector(captureArea)))
        menu.addItem(.separator())
        menu.addItem(menuItem("Open Shotli", #selector(openEditor)))
        menu.addItem(menuItem("Open Screenshot…", #selector(openScreenshot)))
        menu.addItem(menuItem("Open Screenshots Folder", #selector(openScreenshotsFolder)))
        menu.addItem(.separator())
        menu.addItem(menuItem("Check for Updates…", #selector(checkForUpdates)))
        menu.addItem(menuItem("Settings…", #selector(openSettings)))
        menu.addItem(menuItem("Quit Shotli", #selector(quit)))
        item.menu = menu
        statusItem = item
        statusMenu = menu
        refreshCaptureShortcuts()
    }

    func refreshCaptureShortcuts() {
        if let statusMenu { ShotShortcuts.shared.apply(to: statusMenu) }
        if let main = NSApp.mainMenu { ShotShortcuts.shared.apply(to: main) }
        statusItem?.button?.toolTip = ShotShortcuts.shared.statusTip
    }

    private func menuItem(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc private func captureFull() { ScreenCapture.shared.capture(.full) }
    @objc private func captureWindow() { ScreenCapture.shared.capture(.window) }
    @objc private func captureArea() { ScreenCapture.shared.capture(.area) }

    @objc private func openEditor() {
        ScreenCapture.shared.revealEditor()
    }

    @objc private func openScreenshot() {
        ScreenCapture.shared.revealEditor()
        EditorModel.shared.openPanel()
    }

    @objc private func openScreenshotsFolder() {
        let folder = LibraryFolders.screenshots
        try? FileManager.default.createDirectory(at: LibraryFolders.shotli, withIntermediateDirectories: true)
        NSWorkspace.shared.open(FileManager.default.fileExists(atPath: folder.path) ? folder : LibraryFolders.shotli)
    }

    @objc private func checkForUpdates() {
        AppUpdate.shared.check(interactive: true)
    }

    @objc private func openSettings() {
        ScreenCapture.shared.revealEditor()
        ShotliSettings.shared.requestOpen()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

