import AVFoundation
import Foundation

/// One part of a script video: the words, the voice reading them, and the screen recording that goes with them.
struct ScriptPart: Codable, Identifiable, Equatable {
    var id = UUID().uuidString
    var text = ""
    var voice: String?
    var screen: String?
    var voiceSeconds: Double = 0
    var screenSeconds: Double = 0

    /// How long the part runs in the built video. The screen's last frame holds while the voice finishes.
    var length: Double { screen == nil ? 0 : max(voiceSeconds, screenSeconds) }
}

struct ScriptProject: Codable, Identifiable, Equatable {
    var id = UUID().uuidString
    var title = "Untitled script"
    var parts: [ScriptPart] = [ScriptPart()]
    var modified = Date()

    var length: Double { parts.reduce(0) { $0 + $1.length } }
    var recordedParts: [ScriptPart] { parts.filter { $0.screen != nil } }
}

/// Script videos live in Movies/Shotli Scripts, one folder each with its recordings.
final class ScriptStore: ObservableObject {
    static let shared = ScriptStore()

    @Published private(set) var projects: [ScriptProject] = []

    static var root: URL {
        LibraryFolders.home.appendingPathComponent("Movies", isDirectory: true)
            .appendingPathComponent("Shotli Scripts", isDirectory: true)
    }

    private static let fileName = "script.json"

    func folder(_ id: String) -> URL { ScriptStore.root.appendingPathComponent(id, isDirectory: true) }

    func media(_ name: String, in id: String) -> URL { folder(id).appendingPathComponent(name) }

    func load() {
        let manager = FileManager.default
        let folders = (try? manager.contentsOfDirectory(at: ScriptStore.root, includingPropertiesForKeys: nil)) ?? []
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        projects = folders.compactMap { folder in
            guard let data = try? Data(contentsOf: folder.appendingPathComponent(ScriptStore.fileName)) else { return nil }
            return try? decoder.decode(ScriptProject.self, from: data)
        }
        .sorted { $0.modified > $1.modified }
    }

    func create() -> ScriptProject {
        var project = ScriptProject()
        let count = projects.count
        project.title = count == 0 ? "My first script" : "Script \(count + 1)"
        save(project)
        return project
    }

    func save(_ project: ScriptProject) {
        var stored = project
        stored.modified = Date()
        do {
            try FileManager.default.createDirectory(at: folder(project.id), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(stored).write(to: folder(project.id).appendingPathComponent(ScriptStore.fileName), options: .atomic)
        } catch {
            return
        }
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index] = stored
        } else {
            projects.insert(stored, at: 0)
        }
    }

    func delete(_ project: ScriptProject) {
        let url = folder(project.id)
        if (try? FileManager.default.trashItem(at: url, resultingItemURL: nil)) == nil {
            try? FileManager.default.removeItem(at: url)
        }
        projects.removeAll { $0.id == project.id }
    }

    /// Removes a recording that a new take replaced.
    func discard(_ name: String?, in id: String) {
        guard let name else { return }
        try? FileManager.default.removeItem(at: media(name, in: id))
    }
}

enum ScriptBuildError: LocalizedError {
    case nothing
    case unreadable(String)
    case export(String)

    var errorDescription: String? {
        switch self {
        case .nothing: return "Record the screen for at least one part first."
        case .unreadable(let what): return "Couldn't read \(what)."
        case .export(let message): return message.isEmpty ? "Couldn't build the video." : message
        }
    }
}

/// Joins parts end to end. Each part plays its screen recording with its voice; when the voice runs
/// longer, the last frame holds until it finishes.
enum ScriptBuild {
    struct Clip {
        var screen: URL
        var voice: URL?
    }

    struct Plan {
        let composition: AVMutableComposition
        let video: AVMutableVideoComposition
        let length: Double
        let size: CGSize
    }

    static let fps: Int32 = 30
    static let longestSide: CGFloat = 2560

    static func clips(_ project: ScriptProject, store: ScriptStore = .shared) -> [Clip] {
        project.parts.compactMap { part in
            guard let screen = part.screen else { return nil }
            return Clip(screen: store.media(screen, in: project.id), voice: part.voice.map { store.media($0, in: project.id) })
        }
    }

    static func plan(_ clips: [Clip]) throws -> Plan {
        guard !clips.isEmpty else { throw ScriptBuildError.nothing }
        let composition = AVMutableComposition()
        guard let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
              let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw ScriptBuildError.export("")
        }
        struct Segment {
            var range: CMTimeRange
            var size: CGSize
            var transform: CGAffineTransform
        }
        var segments: [Segment] = []
        var cursor = CMTime.zero
        for clip in clips {
            let screen = AVURLAsset(url: clip.screen)
            try load(screen)
            guard let source = screen.tracks(withMediaType: .video).first else {
                throw ScriptBuildError.unreadable("a screen recording")
            }
            let screenRange = source.timeRange
            let screenLength = screenRange.duration
            var voiceLength = CMTime.zero
            if let voiceURL = clip.voice {
                let voice = AVURLAsset(url: voiceURL)
                try load(voice)
                if let voiceSource = voice.tracks(withMediaType: .audio).first {
                    voiceLength = voiceSource.timeRange.duration
                    try audioTrack.insertTimeRange(voiceSource.timeRange, of: voiceSource, at: cursor)
                }
            }
            try videoTrack.insertTimeRange(screenRange, of: source, at: cursor)
            let screenEnd = videoTrack.timeRange.end
            let voiceEnd = cursor + voiceLength
            if voiceEnd > screenEnd {
                // Stretch the final frame to cover the rest of the voice. Scale exactly what was
                // inserted, since a frame can be a little longer than 1/30s.
                let tail = CMTimeMinimum(CMTime(value: 1, timescale: fps), screenLength)
                try videoTrack.insertTimeRange(CMTimeRange(start: screenRange.end - tail, duration: tail), of: source, at: screenEnd)
                let inserted = CMTimeRange(start: screenEnd, end: videoTrack.timeRange.end)
                videoTrack.scaleTimeRange(inserted, toDuration: voiceEnd - screenEnd + inserted.duration)
            }
            let end = videoTrack.timeRange.end
            let shown = source.naturalSize.applying(source.preferredTransform)
            segments.append(Segment(
                range: CMTimeRange(start: cursor, end: end),
                size: CGSize(width: abs(shown.width), height: abs(shown.height)),
                transform: source.preferredTransform
            ))
            cursor = end
        }
        // Instructions must reach the very end of the composition.
        let total = composition.duration
        if let last = segments.indices.last, segments[last].range.end < total {
            segments[last].range = CMTimeRange(start: segments[last].range.start, end: total)
        }
        if audioTrack.segments.isEmpty {
            composition.removeTrack(audioTrack)
        }
        let largest = segments.map(\.size).max { $0.width * $0.height < $1.width * $1.height } ?? CGSize(width: 1920, height: 1080)
        let shrink = min(1, longestSide / max(largest.width, largest.height, 1))
        let render = CGSize(width: even(largest.width * shrink), height: even(largest.height * shrink))
        let video = AVMutableVideoComposition()
        video.renderSize = render
        video.frameDuration = CMTime(value: 1, timescale: fps)
        video.instructions = segments.map { segment in
            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = segment.range
            let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
            let scale = min(render.width / max(segment.size.width, 1), render.height / max(segment.size.height, 1))
            let x = (render.width - segment.size.width * scale) / 2
            let y = (render.height - segment.size.height * scale) / 2
            layer.setTransform(segment.transform
                .concatenating(CGAffineTransform(scaleX: scale, y: scale))
                .concatenating(CGAffineTransform(translationX: x, y: y)), at: segment.range.start)
            instruction.layerInstructions = [layer]
            return instruction
        }
        return Plan(composition: composition, video: video, length: CMTimeGetSeconds(total), size: render)
    }

    static func export(_ plan: Plan, to destination: URL, progress: @escaping (Double) -> Void) throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("shotli-script-\(UUID().uuidString).mp4")
        defer { try? FileManager.default.removeItem(at: temp) }
        guard let exporter = AVAssetExportSession(asset: plan.composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw ScriptBuildError.export("")
        }
        exporter.videoComposition = plan.video
        exporter.outputURL = temp
        exporter.outputFileType = .mp4
        exporter.shouldOptimizeForNetworkUse = true
        let done = DispatchSemaphore(value: 0)
        exporter.exportAsynchronously { done.signal() }
        while done.wait(timeout: .now() + 0.2) == .timedOut {
            progress(Double(exporter.progress))
        }
        guard exporter.status == .completed else {
            throw ScriptBuildError.export(exporter.error?.localizedDescription ?? "")
        }
        progress(1)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: temp, to: destination)
    }

    static func seconds(of url: URL) -> Double {
        let asset = AVURLAsset(url: url)
        try? load(asset)
        let value = CMTimeGetSeconds(asset.duration)
        return value.isFinite ? value : 0
    }

    private static func even(_ value: CGFloat) -> CGFloat {
        max(2, (value / 2).rounded(.down) * 2)
    }

    private static func load(_ asset: AVURLAsset) throws {
        let keys = ["tracks", "duration"]
        let ready = DispatchSemaphore(value: 0)
        asset.loadValuesAsynchronously(forKeys: keys) { ready.signal() }
        _ = ready.wait(timeout: .now() + 8)
        for key in keys {
            var error: NSError?
            if asset.statusOfValue(forKey: key, error: &error) != .loaded {
                throw ScriptBuildError.unreadable(asset.url.lastPathComponent)
            }
        }
    }
}
