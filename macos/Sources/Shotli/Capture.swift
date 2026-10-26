import AppKit

enum CaptureMode {
    case full
    case window
    case area
}

final class ScreenCapture {
    static let shared = ScreenCapture()
    private var task: Process?

    func capture(_ mode: CaptureMode) {
        guard task?.isRunning != true, !AreaSelector.shared.isActive else { return }
        guard ensureCaptureAllowed() else { return }
        if mode == .area {
            hideWindows()
            AreaSelector.shared.begin()
            return
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("shotli-capture-\(UUID().uuidString).png")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        var arguments = ["-x", "-t", "png"]
        switch mode {
        case .full:
            arguments.append("-m")
        case .window:
            arguments.append("-w")
        case .area:
            break
        }
        arguments.append(url.path)
        process.arguments = arguments
        process.terminationHandler = { [weak self] finished in
            DispatchQueue.main.async {
                self?.task = nil
                self?.finish(finished, url: url)
            }
        }
        task = process
        hideWindows()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            do {
                try process.run()
            } catch {
                self?.task = nil
                EditorModel.shared.notice = "Couldn't start a screen capture."
                self?.revealEditor()
            }
        }
    }

    func adopt(_ url: URL) {
        let saved = LibraryFolders.archive(url)
        EditorModel.shared.load(url: saved)
        if saved != url { try? FileManager.default.removeItem(at: url) }
        LibraryModel.shared.refresh()
        revealEditor()
    }

    func revealEditor() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        let windows = NSApp.windows.filter { $0.canBecomeMain }
        let window = windows.first(where: { $0.isVisible }) ?? windows.first
        window?.makeKeyAndOrderFront(nil)
    }

    private func finish(_ process: Process, url: URL) {
        let exists = FileManager.default.fileExists(atPath: url.path)
        guard process.terminationStatus == 0, exists else {
            revealEditor()
            if !CGPreflightScreenCaptureAccess() {
                presentPermissionAlert()
            }
            return
        }
        adopt(url)
    }

    private func hideWindows() {
        for window in NSApp.windows where window.isVisible {
            window.orderOut(nil)
        }
    }

    private func ensureCaptureAllowed() -> Bool {
        let path = Bundle.main.bundlePath
        if path.contains("/AppTranslocation/") || path.hasPrefix("/Volumes/") {
            presentLocationAlert()
            return false
        }
        if CGPreflightScreenCaptureAccess() { return true }
        CGRequestScreenCaptureAccess()
        openScreenRecordingSettings()
        presentPermissionAlert()
        return false
    }

    private func presentLocationAlert() {
        let alert = NSAlert()
        alert.messageText = "Open Shotli from Applications"
        alert.informativeText = "macOS opened this copy from a temporary folder, so the Screen Recording switch cannot stick. Quit Shotli, drag it into Applications, and open that copy."
        alert.addButton(withTitle: "Show Applications")
        alert.addButton(withTitle: "Not Now")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications"))
        }
    }

    private func presentPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Turn on Screen Recording for Shotli"
        alert.informativeText = "macOS is blocking the capture. Shotli never records audio. The Open System Settings button in Apple's dialog often does nothing, so use the button here.\n\nIn Screen & System Audio Recording, turn Shotli on. Then quit Shotli and open it again. If the switch does nothing, select Shotli, click the minus button, and try the capture once more."
        alert.addButton(withTitle: "Open Screen Recording Settings")
        alert.addButton(withTitle: "Not Now")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            openScreenRecordingSettings()
        }
    }

    private func openScreenRecordingSettings() {
        let links = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ScreenCapture",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture",
        ]
        for link in links {
            guard let url = URL(string: link), NSWorkspace.shared.open(url) else { continue }
            return
        }
    }
}

final class WindowKeeper: NSObject, NSWindowDelegate {
    static let shared = WindowKeeper()

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }
}
