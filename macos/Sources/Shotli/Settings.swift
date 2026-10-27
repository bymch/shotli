import AppKit
import ServiceManagement
import SwiftUI

enum ShotliAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    /// Nil lets SwiftUI follow the Mac. Light and Dark override it.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }

    static func resolved(from stored: String?) -> ShotliAppearance {
        guard let stored, let value = ShotliAppearance(rawValue: stored) else { return .system }
        return value
    }

    /// Headless check for `--verify-projects`. It does not draw or touch a picture.
    static func check() -> String? {
        if resolved(from: nil) != .system { return "missing appearance was not System" }
        if resolved(from: "") != .system { return "blank appearance was not System" }
        if resolved(from: "nope") != .system { return "unknown appearance was not System" }
        if resolved(from: "system") != .system { return "system appearance was not System" }
        if resolved(from: "light") != .light || ShotliAppearance.light.colorScheme != .light {
            return "light appearance did not stay light"
        }
        if resolved(from: "dark") != .dark || ShotliAppearance.dark.colorScheme != .dark {
            return "dark appearance did not stay dark"
        }
        if ShotliAppearance.system.colorScheme != nil { return "system appearance forced a scheme" }
        if ShotliAppearance.light.colorScheme == ShotliAppearance.dark.colorScheme {
            return "light and dark appearance matched"
        }
        return nil
    }

    func apply() {
        let next = nsAppearance
        NSApp.appearance = next
        for window in NSApp.windows {
            window.appearance = next
        }
    }
}

final class ShotliSettings: ObservableObject {
    static let shared = ShotliSettings()

    @Published var showMenuBar: Bool
    @Published var checkForUpdates: Bool
    @Published var confirmStartOver: Bool
    @Published var confirmDelete: Bool
    @Published var startIn: LibrarySource
    @Published var sortShots: Bool
    @Published var appearance: ShotliAppearance

    @Published var opensAtLogin = false
    @Published var loginAvailable = false
    @Published var loginNote: String?
    @Published var openRequest = 0

    private let defaults = UserDefaults.standard

    private enum Key {
        static let menuBar = "shotli.showMenuBar"
        static let updates = "shotli.checkForUpdates"
        static let startOver = "shotli.confirmStartOver"
        static let delete = "shotli.confirmDelete"
        static let startIn = "shotli.startIn"
        static let sort = "shotli.sortShots"
        static let appearance = "shotli.appearance"
    }

    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.2.58"
    }

    private init() {
        showMenuBar = Self.storedBool(Key.menuBar, default: true)
        checkForUpdates = Self.storedBool(Key.updates, default: true)
        confirmStartOver = Self.storedBool(Key.startOver, default: true)
        confirmDelete = Self.storedBool(Key.delete, default: true)
        let raw = UserDefaults.standard.string(forKey: Key.startIn) ?? LibrarySource.recent.rawValue
        startIn = LibrarySource(rawValue: raw) ?? .recent
        sortShots = Self.storedBool(Key.sort, default: true)
        appearance = ShotliAppearance.resolved(from: UserDefaults.standard.string(forKey: Key.appearance))
        refreshLoginItem()
        appearance.apply()
    }

    func requestOpen() {
        openRequest += 1
    }

    func setShowMenuBar(_ value: Bool) {
        guard showMenuBar != value else { return }
        showMenuBar = value
        defaults.set(value, forKey: Key.menuBar)
        (NSApp.delegate as? AppDelegate)?.setMenuBarVisible(value)
    }

    func setCheckForUpdates(_ value: Bool) {
        guard checkForUpdates != value else { return }
        checkForUpdates = value
        defaults.set(value, forKey: Key.updates)
    }

    func setConfirmStartOver(_ value: Bool) {
        guard confirmStartOver != value else { return }
        confirmStartOver = value
        defaults.set(value, forKey: Key.startOver)
    }

    func setConfirmDelete(_ value: Bool) {
        guard confirmDelete != value else { return }
        confirmDelete = value
        defaults.set(value, forKey: Key.delete)
    }

    func setStartIn(_ value: LibrarySource) {
        guard startIn != value else { return }
        startIn = value
        defaults.set(value.rawValue, forKey: Key.startIn)
    }

    func setAppearance(_ value: ShotliAppearance) {
        guard appearance != value else { return }
        appearance = value
        defaults.set(value.rawValue, forKey: Key.appearance)
        value.apply()
    }

    func setSortShots(_ value: Bool) {
        guard sortShots != value else { return }
        sortShots = value
        defaults.set(value, forKey: Key.sort)
        if value {
            ShotSorter.shared.schedule(LibraryModel.shared.allShots())
        } else {
            ShotSorter.shared.stop()
        }
    }

    func setOpensAtLogin(_ enabled: Bool) {
        guard loginAvailable else { return }
        guard #available(macOS 13.0, *) else { return }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            opensAtLogin = false
            loginNote = "Put Shotli in Applications before it can open at login."
            return
        }
        refreshLoginItem()
    }

    func refreshLoginItem() {
        guard #available(macOS 13.0, *) else {
            loginAvailable = false
            opensAtLogin = false
            loginNote = "Open at login needs macOS 13 or later."
            return
        }
        loginAvailable = true
        switch SMAppService.mainApp.status {
        case .enabled:
            opensAtLogin = true
            loginNote = nil
        case .requiresApproval:
            opensAtLogin = false
            loginNote = "Allow Shotli in System Settings, under General, Login Items."
        case .notFound:
            opensAtLogin = false
            loginNote = "Put Shotli in Applications before it can open at login."
        case .notRegistered:
            opensAtLogin = false
            loginNote = nil
        @unknown default:
            opensAtLogin = false
            loginNote = nil
        }
    }

    func revealShotliFolder() {
        let folder = LibraryFolders.shotli
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        NSWorkspace.shared.open(folder)
    }

    private static func storedBool(_ key: String, default defaultValue: Bool) -> Bool {
        if UserDefaults.standard.object(forKey: key) == nil { return defaultValue }
        return UserDefaults.standard.bool(forKey: key)
    }
}

struct SettingsPane: View {
    var onDone: (() -> Void)?
    @ObservedObject private var settings = ShotliSettings.shared
    @ObservedObject private var permissions = ShotliPermissions.shared
    @ObservedObject private var shortcuts = ShotShortcuts.shared
    @Environment(\.colorScheme) private var colorScheme

    private var ink: Color { ShotliGlass.ink(colorScheme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Settings")
                        .font(.system(size: 18, weight: .semibold))
                    Text("How Shotli behaves on this Mac.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                Spacer(minLength: 12)
                if let onDone {
                    plainButton("Done", action: onDone)
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 16)
            .padding(.bottom, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    card("Appearance") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("System follows this Mac. Light and Dark stay put when the Mac changes.")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Picker("Appearance", selection: Binding(get: { settings.appearance }, set: { settings.setAppearance($0) })) {
                                ForEach(ShotliAppearance.allCases) { mode in
                                    Text(mode.title).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .accessibilityLabel("Appearance")
                        }
                        .padding(.vertical, 10)
                    }
                    card("Permissions") {
                        ForEach(Array(ShotliPermissions.Kind.allCases.enumerated()), id: \.element.id) { index, kind in
                            if index > 0 { divider }
                            permissionRow(kind)
                        }
                    }
                    card("General") {
                        toggleRow(
                            "Show Shotli in the menu bar",
                            "Capture a full screen, a window, or an area without opening the window.",
                            isOn: Binding(get: { settings.showMenuBar }, set: { settings.setShowMenuBar($0) })
                        )
                        divider
                        toggleRow(
                            "Open Shotli at login",
                            settings.loginNote ?? "Shotli is ready in the menu bar after you sign in.",
                            isOn: Binding(get: { settings.opensAtLogin }, set: { settings.setOpensAtLogin($0) }),
                            enabled: settings.loginAvailable
                        )
                        divider
                        toggleRow(
                            "Check for updates automatically",
                            "Look for a new version when Shotli opens.",
                            isOn: Binding(get: { settings.checkForUpdates }, set: { settings.setCheckForUpdates($0) })
                        )
                    }
                    card("Shortcuts") {
                        Text("These work while you are in another app. Click a shortcut, then press the keys. Delete clears it.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 8)
                            .padding(.bottom, 4)
                        shortcutRow(.full, "Full screen", "The main display.")
                        divider
                        shortcutRow(.window, "Window", "Click the window you want.")
                        divider
                        shortcutRow(.area, "Area", "Drag a box, then press Return.")
                        if let note = shortcuts.note {
                            Text(note)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.bottom, 8)
                        }
                        divider
                        HStack {
                            Spacer(minLength: 0)
                            plainButton("Restore defaults", fill: cardButton) { shortcuts.restoreDefaults() }
                        }
                        .padding(.vertical, 8)
                    }
                    card("Library") {
                        HStack(alignment: .center, spacing: 16) {
                            copy(
                                "Start in",
                                "Which screenshot list is selected after you leave Projects."
                            )
                            Picker("Start in", selection: Binding(get: { settings.startIn }, set: { settings.setStartIn($0) })) {
                                ForEach(LibrarySource.allCases) { source in
                                    Text(source.title).tag(source)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .frame(width: 148)
                        }
                        .padding(.vertical, 8)
                        divider
                        toggleRow(
                            "Sort screenshots",
                            AppleShotKind.detail,
                            isOn: Binding(get: { settings.sortShots }, set: { settings.setSortShots($0) })
                        )
                        divider
                        HStack(alignment: .center, spacing: 16) {
                            copy("Shotli folder", shotliPath)
                            plainButton("Show in Finder", fill: cardButton) { settings.revealShotliFolder() }
                        }
                        .padding(.vertical, 8)
                    }
                    card("Editing") {
                        toggleRow(
                            "Ask before Start Over",
                            "Confirm before the screenshot you are editing is cleared.",
                            isOn: Binding(get: { settings.confirmStartOver }, set: { settings.setConfirmStartOver($0) })
                        )
                        divider
                        toggleRow(
                            "Ask before deleting",
                            "Confirm before selected screenshots move to the Trash.",
                            isOn: Binding(get: { settings.confirmDelete }, set: { settings.setConfirmDelete($0) })
                        )
                    }
                    card("Shotli") {
                        HStack(alignment: .center, spacing: 16) {
                            copy("Version", "The copy of Shotli running on this Mac.")
                            Text(ShotliSettings.version)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                        divider
                        HStack(spacing: 8) {
                            plainButton("Check for Updates", fill: cardButton) { AppUpdate.shared.check(interactive: true) }
                            plainButton("Changelog", fill: cardButton) { Changelog.show() }
                            plainButton("Keyboard Shortcuts", fill: cardButton) { showShotliShortcuts() }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 8)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 24)
                .frame(maxWidth: 680, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ShotliGlass.page(colorScheme))
        .onAppear {
            settings.refreshLoginItem()
            permissions.beginWatching()
        }
        .onDisappear { permissions.endWatching() }
    }

    private func shortcutRow(_ action: CaptureAction, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .center, spacing: 16) {
            copy(title, detail)
            ShortcutWell(action: action)
                .frame(width: 168, height: 28)
                .help("Click, then press a shortcut. Delete clears it.")
        }
        .padding(.vertical, 8)
    }

    private func permissionRow(_ kind: ShotliPermissions.Kind) -> some View {
        let granted = permissions.isGranted(kind)
        return HStack(alignment: .center, spacing: 16) {
            Image(systemName: kind.symbol)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 16)
                .foregroundColor(granted ? ink : .secondary)
            copy(kind.title, kind.detail)
            if granted {
                Label("Allowed", systemImage: "checkmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .labelStyle(.titleAndIcon)
            } else {
                plainButton("Allow", fill: cardButton) {
                    permissions.allow(kind)
                }
            }
        }
        .padding(.vertical, 8)
    }

    private var shotliPath: String {
        LibraryFolders.shotli.path.replacingOccurrences(of: LibraryFolders.home.path, with: "~")
    }

    private var divider: some View {
        Rectangle()
            .fill(ShotliGlass.hairline(colorScheme))
            .frame(height: 1)
    }

    private func card<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(ShotliGlass.surface(colorScheme)))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(ShotliGlass.hairline(colorScheme), lineWidth: 1))
        }
    }

    private func toggleRow(_ title: String, _ detail: String, isOn: Binding<Bool>, enabled: Bool = true) -> some View {
        HStack(alignment: .center, spacing: 16) {
            copy(title, detail)
            Toggle(title, isOn: isOn)
                .toggleStyle(.switch)
                .labelsHidden()
                .disabled(!enabled)
        }
        .padding(.vertical, 8)
    }

    private func copy(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(ink)
            Text(detail)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var cardButton: Color { ShotliGlass.surfaceSecondary(colorScheme) }

    private func plainButton(_ title: String, fill: Color? = nil, action: @escaping () -> Void) -> some View {
        let plate = fill ?? ShotliGlass.surface(colorScheme)
        return Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(ink)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(plate))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(ShotliGlass.line(colorScheme), lineWidth: 1))
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

func showShotliShortcuts() {
    let alert = NSAlert()
    alert.messageText = "Shortcuts"
    let shortcuts = ShotShortcuts.shared
    alert.informativeText = """
    Capture full screen \(shortcuts.label(for: .full))
    Capture window \(shortcuts.label(for: .window))
    Capture area \(shortcuts.label(for: .area))

    Change a capture shortcut in Settings. Delete clears it. These work from any app.

    Undo ⌘Z
    Redo ⌘⇧Z, or ⌘Y
    Open ⌘O
    Library ⌘L
    Settings ⌘,
    Export ⌘S, or ⌘E
    Copy ⌘C, or ⌘⇧C
    Paste an image ⌘V
    Fit ⌘0
    Delete Backspace

    V select, R rectangle, F fill, C circle, L line, A arrow, D draw, T text, N number, P pixelate, B blur, K crop

    Hold Shift to keep a line or box square. Scroll to move around the canvas. Pinch, or hold ⌘ and scroll, to zoom. Fit puts the canvas back in the window, and 100% shows it at actual size.
    """
    alert.addButton(withTitle: "OK")
    alert.runModal()
}
