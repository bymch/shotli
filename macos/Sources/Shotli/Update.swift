import AppKit

final class AppUpdate {
    static let shared = AppUpdate()
    private var busy = false
    private init() {}

    func checkOnLaunch() {
        let key = "shotli.lastUpdateCheck"
        let last = UserDefaults.standard.double(forKey: key)
        if last > 0, Date().timeIntervalSince1970 - last < 60 * 60 * 12 { return }
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: key)
        check(interactive: false)
    }

    func check(interactive: Bool) {
        guard !busy else { return }
        busy = true
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/bymch/shotli/releases/latest")!)
        request.setValue("Shotli", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        URLSession.shared.dataTask(with: request) { data, _, error in
            DispatchQueue.main.async {
                guard let data, error == nil, let release = Self.parse(data) else {
                    self.busy = false
                    if interactive { EditorModel.shared.notice = "Couldn't check for an update." }
                    return
                }
                let local = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
                guard Self.isNewer(release.version, than: local) else {
                    self.busy = false
                    if interactive { EditorModel.shared.notice = "You're on the latest Shotli." }
                    return
                }
                self.offer(release)
            }
        }.resume()
    }

    private func offer(_ release: Release) {
        let alert = NSAlert()
        alert.messageText = "Shotli \(release.version) is ready"
        alert.informativeText = "Download it and replace this copy? Shotli quits, puts the new version in place, and opens again. You don't delete the old one first."
        alert.addButton(withTitle: "Download and replace")
        alert.addButton(withTitle: "Not now")
        guard alert.runModal() == .alertFirstButtonReturn else {
            busy = false
            return
        }
        EditorModel.shared.notice = "Downloading Shotli \(release.version)…"
        download(release)
    }

    private func download(_ release: Release) {
        URLSession.shared.downloadTask(with: release.zipURL) { location, _, error in
            guard let location, error == nil else {
                DispatchQueue.main.async {
                    self.busy = false
                    EditorModel.shared.notice = "Couldn't download the update."
                }
                return
            }
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("shotli-update-\(UUID().uuidString)")
            let zip = folder.appendingPathComponent("Shotli-mac.zip")
            do {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                try FileManager.default.moveItem(at: location, to: zip)
                let extract = folder.appendingPathComponent("app")
                try FileManager.default.createDirectory(at: extract, withIntermediateDirectories: true)
                let unpack = Process()
                unpack.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
                unpack.arguments = ["-x", "-k", zip.path, extract.path]
                try unpack.run()
                unpack.waitUntilExit()
                guard unpack.terminationStatus == 0, let app = Self.findApp(in: extract) else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                try self.swap(app, into: Self.destination())
            } catch {
                DispatchQueue.main.async {
                    self.busy = false
                    EditorModel.shared.notice = "Couldn't install the update."
                }
            }
        }.resume()
    }

    private func swap(_ app: URL, into destination: URL) throws {
        let scriptURL = FileManager.default.temporaryDirectory.appendingPathComponent("shotli-update-\(UUID().uuidString).sh")
        let script = """
        #!/bin/bash
        sleep 1
        for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
          if ! pgrep -x Shotli >/dev/null; then
            break
          fi
          sleep 0.3
        done
        rm -rf \(shellQuoted(destination.path))
        ditto \(shellQuoted(app.path)) \(shellQuoted(destination.path))
        xattr -dr com.apple.quarantine \(shellQuoted(destination.path)) || true
        open \(shellQuoted(destination.path))
        """
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
        let launch = Process()
        launch.executableURL = URL(fileURLWithPath: "/bin/bash")
        launch.arguments = ["-c", "nohup \(shellQuoted(scriptURL.path)) >/tmp/shotli-update.log 2>&1 &"]
        try launch.run()
        launch.waitUntilExit()
        DispatchQueue.main.async {
            NSApp.terminate(nil)
        }
    }

    private static func destination() -> URL {
        let bundle = Bundle.main.bundleURL
        let parent = bundle.deletingLastPathComponent()
        if bundle.path.hasPrefix("/Volumes/") || !FileManager.default.isWritableFile(atPath: parent.path) {
            return URL(fileURLWithPath: "/Applications/Shotli.app")
        }
        return bundle
    }

    private static func findApp(in folder: URL) -> URL? {
        guard let items = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else { return nil }
        if let app = items.first(where: { $0.lastPathComponent == "Shotli.app" }) { return app }
        for item in items where item.hasDirectoryPath {
            if let nested = findApp(in: item) { return nested }
        }
        return nil
    }

    private struct Release {
        var version: String
        var zipURL: URL
    }

    private static func parse(_ data: Data) -> Release? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String,
              let assets = json["assets"] as? [[String: Any]] else { return nil }
        guard let asset = assets.first(where: { ($0["name"] as? String) == "Shotli-mac.zip" }),
              let urlString = asset["browser_download_url"] as? String,
              let url = URL(string: urlString) else { return nil }
        let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        return Release(version: version, zipURL: url)
    }

    private static func isNewer(_ remote: String, than local: String) -> Bool {
        let left = remote.split(separator: ".").map { Int($0) ?? 0 }
        let right = local.split(separator: ".").map { Int($0) ?? 0 }
        for index in 0..<max(left.count, right.count) {
            let a = index < left.count ? left[index] : 0
            let b = index < right.count ? right[index] : 0
            if a != b { return a > b }
        }
        return false
    }

    private func shellQuoted(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
