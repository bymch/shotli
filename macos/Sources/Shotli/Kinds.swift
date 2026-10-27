import AppKit
import ImageIO
import Vision
#if canImport(FoundationModels)
import FoundationModels
#endif

enum ShotKind: String, CaseIterable, Identifiable, Codable {
    case code, website, document, conversation, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .code: return "Code"
        case .website: return "Websites"
        case .document: return "Documents"
        case .conversation: return "Conversations"
        case .other: return "Other"
        }
    }

    var emptyNoun: String {
        switch self {
        case .code: return "code"
        case .website: return "websites"
        case .document: return "documents"
        case .conversation: return "conversations"
        case .other: return "other screenshots"
        }
    }

    var symbol: String {
        switch self {
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .website: return "globe"
        case .document: return "doc.text"
        case .conversation: return "text.bubble"
        case .other: return "square.on.square"
        }
    }

    var guidance: String {
        switch self {
        case .code: return "source code, a terminal, a diff, or a developer tool"
        case .website: return "a web browser, a web page, or search results"
        case .document: return "a document, note, PDF, slide, or article"
        case .conversation: return "a chat, email thread, or messaging app"
        case .other: return "anything that fits none of the others"
        }
    }
}

enum ShotKindRules {
    static func classify(_ text: String) -> ShotKind {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        let code = hits(codeWords, in: folded)
        let chat = hits(chatWords, in: folded)
        let web = folded.contains("https://") || folded.contains("http://") || folded.contains("www.")
            || folded.contains("search or enter")
        if chat >= 2, code < 3 { return .conversation }
        if code >= 5 { return .code }
        if code >= 3, !web { return .code }
        if web { return .website }
        if code >= 3 { return .code }
        if folded.count > 320 { return .document }
        return .other
    }

    private static func hits(_ words: [String], in text: String) -> Int {
        words.reduce(0) { $0 + (text.contains($1) ? 1 : 0) }
    }

    private static let codeWords = [
        "func ", "return ", "import ", "const ", "let ", "var ", "class ", "def ",
        "public ", "private ", "#include", "console.", "=>", "();", "undefined", "traceback",
    ]
    private static let chatWords = [
        "imessage", "slack", "discord", "whatsapp", "telegram", "delivered",
        "type a message", "direct message", "unread message",
    ]
}

enum AppleShotKind {
    static var detail: String {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            if SystemLanguageModel.default.availability == .available {
                #if SHOTLI_APPLE_VISION
                if #available(macOS 27.0, *), SystemLanguageModel.default.capabilities.contains(.vision) {
                    return "Apple Intelligence looks at each screenshot and files it as code, a website, a document, a conversation, or other. It stays on this Mac."
                }
                #endif
                return "Apple Intelligence reads the text in each screenshot and files it as code, a website, a document, a conversation, or other. It stays on this Mac."
            }
            return "Apple Intelligence is turned off. Shotli reads the text in each screenshot and sorts it on this Mac."
        }
        #endif
        return "Shotli reads the text in each screenshot and sorts it on this Mac. Nothing is uploaded."
    }

    static func classify(text: String, image: CGImage?) async -> ShotKind? {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            return await ModelSort.classify(text: text, image: image)
        }
        #endif
        return nil
    }
}

#if canImport(FoundationModels)
@available(macOS 26.0, *)
private enum ModelSort {
    @Generable
    enum Label {
        case code, website, document, conversation, other

        var kind: ShotKind {
            switch self {
            case .code: return .code
            case .website: return .website
            case .document: return .document
            case .conversation: return .conversation
            case .other: return .other
            }
        }
    }

    static func classify(text: String, image: CGImage?) async -> ShotKind? {
        guard SystemLanguageModel.default.availability == .available else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let prompt = """
        File this screenshot into one category.
        \(ShotKind.allCases.map { "- \($0.rawValue): \($0.guidance)" }.joined(separator: "\n"))

        Text in the screenshot, possibly partial:
        \(trimmed.isEmpty ? "none" : String(trimmed.prefix(1800)))
        """
        let session = LanguageModelSession(instructions: "You sort screenshots into a library. Choose the single best category. Do not invent names or products that are not in the screenshot.")
        let options = GenerationOptions(temperature: 0.2)
        do {
            #if SHOTLI_APPLE_VISION
            if #available(macOS 27.0, *), let image, SystemLanguageModel.default.capabilities.contains(.vision) {
                return try await session.respond(generating: Label.self, options: options) {
                    prompt
                    Attachment(image)
                }.content.kind
            }
            #endif
            guard !trimmed.isEmpty else { return nil }
            return try await session.respond(to: prompt, generating: Label.self, options: options).content.kind
        } catch {
            return nil
        }
    }
}
#endif

/// Reads screenshots on this Mac and remembers the category for each file.
final class ShotSorter {
    static let shared = ShotSorter()

    private struct Record: Codable {
        var modified: TimeInterval
        var kind: String
        var classifier: String
        var modelTried: Bool
    }

    private struct File: Codable {
        var version: Int
        var items: [String: Record]
    }

    private let queue = DispatchQueue(label: "shotli.kinds")
    private var items: [String: Record] = [:]
    private var queued: [LibraryShot] = []
    private var working = false
    private var loaded = false
    private let version = 1

    private init() {}

    func knownKinds(in shots: [LibraryShot]) -> [String: ShotKind] {
        queue.sync {
            loadIfNeeded()
            var found: [String: ShotKind] = [:]
            for shot in shots {
                guard let record = items[shot.id],
                      abs(record.modified - shot.modified.timeIntervalSince1970) < 1,
                      let kind = ShotKind(rawValue: record.kind) else { continue }
                found[shot.id] = kind
            }
            return found
        }
    }

    func schedule(_ shots: [LibraryShot]) {
        queue.async {
            guard ShotliSettings.shared.sortShots else {
                self.queued = []
                self.publishSorting(false)
                return
            }
            self.loadIfNeeded()
            self.queued = shots
            self.pump()
        }
    }

    func stop() {
        queue.async {
            self.queued = []
            self.publishSorting(false)
        }
    }

    private func pump() {
        guard ShotliSettings.shared.sortShots else {
            queued = []
            publishSorting(false)
            return
        }
        guard !working else { return }
        guard let shot = queued.first(where: { needsWork($0) }) else {
            publishSorting(false)
            return
        }
        working = true
        publishSorting(true)
        Task.detached(priority: .utility) {
            let image = Self.thumbnail(shot.url)
            let text = image.flatMap(Self.recognize) ?? ""
            let rules = ShotKindRules.classify(text)
            self.queue.async {
                self.store(shot, Outcome(kind: rules, classifier: "rules", modelTried: false))
            }
            let model = await AppleShotKind.classify(text: text, image: image)
            self.queue.async {
                if let model {
                    self.store(shot, Outcome(kind: model, classifier: "model", modelTried: true))
                } else {
                    self.store(shot, Outcome(kind: rules, classifier: "rules", modelTried: AppleIntelligenceGate.isAvailable))
                }
                self.working = false
                self.pump()
            }
        }
    }

    private func needsWork(_ shot: LibraryShot) -> Bool {
        guard let record = items[shot.id], abs(record.modified - shot.modified.timeIntervalSince1970) < 1 else { return true }
        if record.classifier == "model" || record.modelTried { return false }
        return AppleIntelligenceGate.isAvailable
    }

    private func store(_ shot: LibraryShot, _ outcome: Outcome) {
        let previous = items[shot.id]
        let modified = shot.modified.timeIntervalSince1970
        let unchanged = previous?.kind == outcome.kind.rawValue
            && previous?.classifier == outcome.classifier
            && previous?.modelTried == outcome.modelTried
            && abs((previous?.modified ?? -1) - modified) < 1
        items[shot.id] = Record(modified: modified, kind: outcome.kind.rawValue, classifier: outcome.classifier, modelTried: outcome.modelTried)
        if !unchanged {
            save()
            DispatchQueue.main.async {
                LibraryModel.shared.setKind(id: shot.id, kind: outcome.kind)
            }
        }
    }

    private struct Outcome {
        var kind: ShotKind
        var classifier: String
        var modelTried: Bool
    }

    private static func thumbnail(_ url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary) else { return nil }
        return CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 1600,
        ] as CFDictionary)
    }

    private static func recognize(_ image: CGImage) -> String? {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        try? VNImageRequestHandler(cgImage: image).perform([request])
        let lines = ((request.results as? [VNRecognizedTextObservation]) ?? []).sorted { $0.boundingBox.maxY > $1.boundingBox.maxY }
        let text = lines.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
        return text.isEmpty ? nil : text
    }

    private func publishSorting(_ value: Bool) {
        DispatchQueue.main.async {
            LibraryModel.shared.setSorting(value)
        }
    }

    private func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true
        guard let data = try? Data(contentsOf: storeURL),
              let file = try? JSONDecoder().decode(File.self, from: data),
              file.version == version else { return }
        items = file.items
    }

    private func save() {
        let file = File(version: version, items: items)
        guard let data = try? JSONEncoder().encode(file) else { return }
        let url = storeURL
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }

    private var storeURL: URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return root.appendingPathComponent("Shotli", isDirectory: true).appendingPathComponent("kinds.json")
    }
}

enum AppleIntelligenceGate {
    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            return SystemLanguageModel.default.availability == .available
        }
        #endif
        return false
    }
}
