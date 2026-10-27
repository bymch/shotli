import AppKit
import SwiftUI

/// Live permission status. macOS does not tell the app when a Privacy switch
/// changes, so Settings polls while it is open.
final class ShotliPermissions: ObservableObject {
    static let shared = ShotliPermissions()

    enum Kind: String, CaseIterable, Identifiable {
        case screenRecording, desktop, documents, downloads

        var id: String { rawValue }

        var title: String {
            switch self {
            case .screenRecording: return "Screen Recording"
            case .desktop: return "Desktop"
            case .documents: return "Documents"
            case .downloads: return "Downloads"
            }
        }

        var detail: String {
            switch self {
            case .screenRecording: return "Needed to capture the screen."
            case .desktop: return "Needed to list pictures on the Desktop."
            case .documents: return "Needed when screenshots are saved in Documents."
            case .downloads: return "Needed when screenshots are saved in Downloads."
            }
        }

        var symbol: String {
            switch self {
            case .screenRecording: return "camera.viewfinder"
            case .desktop: return "menubar.dock.rectangle"
            case .documents: return "doc.text"
            case .downloads: return "arrow.down.circle"
            }
        }

        var folder: URL? {
            switch self {
            case .screenRecording: return nil
            case .desktop: return LibraryFolders.desktop
            case .documents: return LibraryFolders.documents
            case .downloads: return LibraryFolders.downloads
            }
        }

        fileprivate var settingsAnchors: [String] {
            switch self {
            case .screenRecording:
                return ["Privacy_ScreenCapture"]
            case .desktop, .documents, .downloads:
                return ["Privacy_FilesAndFolders", "Privacy_DesktopFolder"]
            }
        }
    }

    enum State: Equatable {
        case unknown, allowed, denied
    }

    @Published private(set) var states: [Kind: State] = [:]

    private var timer: Timer?
    private var watchers = 0

    private init() {}

    func state(_ kind: Kind) -> State {
        states[kind] ?? .unknown
    }

    func isGranted(_ kind: Kind) -> Bool {
        state(kind) == .allowed
    }

    func beginWatching() {
        watchers += 1
        refreshScreen()
        recheckKnownFolders()
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.refreshScreen()
            self?.recheckKnownFolders()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func endWatching() {
        watchers = max(0, watchers - 1)
        guard watchers == 0 else { return }
        timer?.invalidate()
        timer = nil
    }

    func allow(_ kind: Kind) {
        switch kind {
        case .screenRecording:
            refreshScreen()
            if state(.screenRecording) != .allowed {
                if !CGRequestScreenCaptureAccess() {
                    openSettings(kind)
                }
                refreshScreen()
            }
        case .desktop, .documents, .downloads:
            guard let folder = kind.folder else { return }
            let allowed = Self.canRead(folder)
            set(kind, allowed ? .allowed : .denied)
            if !allowed { openSettings(kind) }
        }
    }

    /// Called from the library scan. A missing folder is left unknown so a
    /// folder Shotli has not created yet is not shown as denied.
    func note(folder: URL, allowed: Bool) {
        guard let kind = kind(for: folder) else { return }
        let state: State = allowed ? .allowed : .denied
        let apply = { self.set(kind, state) }
        if Thread.isMainThread {
            apply()
        } else {
            DispatchQueue.main.async(execute: apply)
        }
    }

    private func refreshScreen() {
        set(.screenRecording, CGPreflightScreenCaptureAccess() ? .allowed : .denied)
    }

    private func recheckKnownFolders() {
        for kind in [Kind.desktop, .documents, .downloads] {
            guard state(kind) != .unknown, let folder = kind.folder else { continue }
            guard FileManager.default.fileExists(atPath: folder.path) else { continue }
            set(kind, Self.canRead(folder) ? .allowed : .denied)
        }
    }

    private func set(_ kind: Kind, _ state: State) {
        guard states[kind] != state else { return }
        states[kind] = state
    }

    private func kind(for folder: URL) -> Kind? {
        let path = folder.standardizedFileURL.path
        for kind in [Kind.desktop, .documents, .downloads] {
            guard let candidate = kind.folder else { continue }
            if candidate.standardizedFileURL.path == path { return kind }
        }
        return nil
    }

    private static func canRead(_ folder: URL) -> Bool {
        (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) != nil
    }

    private func openSettings(_ kind: Kind) {
        let bases = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?",
            "x-apple.systempreferences:com.apple.preference.security?",
        ]
        for anchor in kind.settingsAnchors {
            for base in bases {
                guard let url = URL(string: base + anchor), NSWorkspace.shared.open(url) else { continue }
                return
            }
        }
    }
}
