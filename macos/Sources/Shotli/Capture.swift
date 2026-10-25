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
        guard task?.isRunning != true else { return }
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
            arguments.append("-i")
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
        for window in NSApp.windows where window.isVisible {
            window.orderOut(nil)
        }
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

    func revealEditor() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        let windows = NSApp.windows.filter { $0.canBecomeMain }
        let window = windows.first(where: { $0.isVisible }) ?? windows.first
        window?.makeKeyAndOrderFront(nil)
    }

    private func finish(_ process: Process, url: URL) {
        defer { revealEditor() }
        let exists = FileManager.default.fileExists(atPath: url.path)
        guard process.terminationStatus == 0, exists else { return }
        let saved = LibraryFolders.archive(url)
        EditorModel.shared.load(url: saved)
        if saved != url { try? FileManager.default.removeItem(at: url) }
        LibraryModel.shared.refresh()
    }
}

final class WindowKeeper: NSObject, NSWindowDelegate {
    static let shared = WindowKeeper()

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }
}
