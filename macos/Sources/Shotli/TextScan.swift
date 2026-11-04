import AppKit
import SwiftUI
import Vision

struct ScanWord: Equatable {
    var text: String
    var range: NSRange
    var rect: CGRect
}

struct ScanLine: Equatable {
    var text: String
    var rect: CGRect
    var words: [ScanWord]
}

/// Reads text and where it sits. Rects use image pixels from the top left, the same space as annotations.
enum TextScan {
    static func lines(in image: CGImage) -> [ScanLine] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        // Correction turns keys and addresses into dictionary words.
        request.usesLanguageCorrection = false
        try? VNImageRequestHandler(cgImage: image).perform([request])
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        func pixels(_ box: CGRect) -> CGRect {
            CGRect(x: box.minX * width, y: (1 - box.maxY) * height, width: box.width * width, height: box.height * height)
        }
        let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
        return observations.compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            let text = candidate.string
            let lineRect = pixels(observation.boundingBox)
            let words = wordRanges(in: text).map { range -> ScanWord in
                let box = Range(range, in: text).flatMap { try? candidate.boundingBox(for: $0)?.boundingBox }
                return ScanWord(text: (text as NSString).substring(with: range), range: range, rect: box.map(pixels) ?? lineRect)
            }
            return ScanLine(text: text, rect: lineRect, words: words)
        }
    }

    /// Reading order, without words the picture does not show: outside the crop or under a redaction.
    static func visibleText(_ lines: [ScanLine], visible: CGRect?, hidden: [CGRect]) -> String {
        func shows(_ word: ScanWord) -> Bool {
            let center = CGPoint(x: word.rect.midX, y: word.rect.midY)
            if let visible, !visible.contains(center) { return false }
            return !hidden.contains { $0.contains(center) }
        }
        let kept: [ScanLine] = lines.compactMap { line in
            let words = line.words.filter(shows)
            guard !words.isEmpty else { return nil }
            var next = line
            next.words = words
            return next
        }
        var rows: [[ScanLine]] = []
        for line in kept.sorted(by: { $0.rect.minY < $1.rect.minY }) {
            if let first = rows.last?.first, line.rect.midY <= first.rect.maxY {
                rows[rows.count - 1].append(line)
            } else {
                rows.append([line])
            }
        }
        return rows.map { row in
            row.sorted { $0.rect.minX < $1.rect.minX }
                .map { $0.words.map(\.text).joined(separator: " ") }
                .joined(separator: "  ")
        }.joined(separator: "\n")
    }

    private static func wordRanges(in text: String) -> [NSRange] {
        guard let regex = try? NSRegularExpression(pattern: "\\S+") else { return [] }
        return regex.matches(in: text, range: NSRange(location: 0, length: (text as NSString).length)).map(\.range)
    }
}

enum SensitiveKind: String, CaseIterable {
    case secret, card, email, phone

    var title: String {
        switch self {
        case .secret: return "Key or password"
        case .card: return "Card number"
        case .email: return "Email"
        case .phone: return "Phone number"
        }
    }

    var symbol: String {
        switch self {
        case .secret: return "key"
        case .card: return "creditcard"
        case .email: return "envelope"
        case .phone: return "phone"
        }
    }
}

struct SensitiveFinding: Identifiable, Equatable {
    var id = UUID().uuidString
    var kind: SensitiveKind
    var preview: String
    var rect: CGRect
}

enum SensitiveText {
    private static let keyPatterns = [
        "\\b(?:sk|pk|rk)[-_](?:live|test|ant|proj)[-_A-Za-z0-9]{12,}",
        "\\bsk-[A-Za-z0-9_-]{20,}",
        "\\b(?:ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{20,}",
        "\\bgithub_pat_[A-Za-z0-9_]{20,}",
        "\\bglpat-[A-Za-z0-9_-]{16,}",
        "\\bxox[abeoprs]-[A-Za-z0-9-]{10,}",
        "\\b(?:AKIA|ASIA)[A-Z0-9]{16}\\b",
        "\\bAIza[A-Za-z0-9_-]{30,}",
        "\\bnpm_[A-Za-z0-9]{30,}",
        "\\bSG\\.[A-Za-z0-9_-]{16,}\\.[A-Za-z0-9_-]{16,}",
        "\\bwhsec_[A-Za-z0-9]{16,}",
        "\\beyJ[A-Za-z0-9_-]{8,}\\.[A-Za-z0-9_-]{8,}\\.[A-Za-z0-9_-]{6,}",
    ]
    private static let labelled = "(?i)\\b(?:api[ _-]?key|secret|token|password|passwd|pwd|authorization)\\b[\"']?\\s*[:=]\\s*[\"']?(?:bearer\\s+)?([^\\s\"',;]{4,})"
    private static let bearer = "(?i)\\bbearer\\s+([A-Za-z0-9._~+/=-]{8,})"
    private static let longToken = "\\b[A-Za-z0-9_-]{32,}\\b"
    private static let email = "(?i)[A-Z0-9._%+-]+@[A-Z0-9-]+(?:\\.[A-Z0-9-]+)*\\.[A-Z]{2,}"
    private static let cardRun = "\\b\\d(?:[ -]?\\d){12,18}\\b"

    /// Stronger kinds first. A later match overlapping an earlier one is dropped.
    static func matches(in text: String) -> [(kind: SensitiveKind, range: NSRange)] {
        var found: [(kind: SensitiveKind, range: NSRange)] = []
        func add(_ kind: SensitiveKind, _ range: NSRange) {
            guard range.location != NSNotFound, range.length > 0 else { return }
            if found.contains(where: { NSIntersectionRange($0.range, range).length > 0 }) { return }
            found.append((kind, range))
        }
        for pattern in keyPatterns {
            for match in all(pattern, in: text) { add(.secret, match.range) }
        }
        for match in all(labelled, in: text) { add(.secret, match.range(at: 1)) }
        for match in all(bearer, in: text) { add(.secret, match.range(at: 1)) }
        for match in all(cardRun, in: text) where isCard((text as NSString).substring(with: match.range)) {
            add(.card, match.range)
        }
        for match in all(email, in: text) { add(.email, match.range) }
        for range in phoneRanges(in: text) { add(.phone, range) }
        for match in all(longToken, in: text) where isMixed((text as NSString).substring(with: match.range)) {
            add(.secret, match.range)
        }
        return found.sorted { $0.range.location < $1.range.location }
    }

    static func findings(in lines: [ScanLine], bounds: CGSize, covered: [CGRect]) -> [SensitiveFinding] {
        let limit = CGRect(origin: .zero, size: bounds)
        var results: [SensitiveFinding] = []
        for line in lines {
            for match in matches(in: line.text) {
                let touching = line.words.filter { NSIntersectionRange($0.range, match.range).length > 0 }
                let boxes = touching.isEmpty ? [line.rect] : touching.map(\.rect)
                let joined = boxes.dropFirst().reduce(boxes[0]) { $0.union($1) }
                let rect = joined.insetBy(dx: -3, dy: -3).intersection(limit)
                guard !rect.isNull, rect.width >= 2, rect.height >= 2 else { continue }
                let center = CGPoint(x: rect.midX, y: rect.midY)
                if covered.contains(where: { $0.contains(center) }) { continue }
                let value = (line.text as NSString).substring(with: match.range)
                results.append(SensitiveFinding(kind: match.kind, preview: mask(value), rect: rect))
            }
        }
        return results
    }

    static func isLuhnValid(_ digits: String) -> Bool {
        var sum = 0
        for (index, character) in digits.reversed().enumerated() {
            guard var value = character.wholeNumberValue else { return false }
            if index % 2 == 1 {
                value *= 2
                if value > 9 { value -= 9 }
            }
            sum += value
        }
        return !digits.isEmpty && sum % 10 == 0
    }

    private static func isCard(_ value: String) -> Bool {
        // Grouped numbers count even if one digit was misread. Bare runs need the checksum,
        // because plenty of long numbers on screen are not cards.
        if value.range(of: "^\\d{4}([ -])\\d{4}\\1\\d{4}\\1\\d{4}$", options: .regularExpression) != nil { return true }
        if value.range(of: "^\\d{4}[ -]\\d{6}[ -]\\d{5}$", options: .regularExpression) != nil { return true }
        let digits = value.filter(\.isNumber)
        return (13...19).contains(digits.count) && isLuhnValid(digits)
    }

    private static func phoneRanges(in text: String) -> [NSRange] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.phoneNumber.rawValue) else { return [] }
        let whole = NSRange(location: 0, length: (text as NSString).length)
        return detector.matches(in: text, range: whole).compactMap { match in
            let value = (text as NSString).substring(with: match.range)
            let digits = value.filter(\.isNumber).count
            guard (7...15).contains(digits) else { return nil }
            if value.range(of: "^\\d{4}-\\d{2}-\\d{2}$", options: .regularExpression) != nil { return nil }
            return match.range
        }
    }

    private static func isMixed(_ value: String) -> Bool {
        value.contains(where: \.isUppercase) && value.contains(where: \.isLowercase) && value.contains(where: \.isNumber)
    }

    private static func mask(_ value: String) -> String {
        value.count > 8 ? "\(value.prefix(4))•••\(value.suffix(2))" : "\(value.prefix(1))•••"
    }

    private static func all(_ pattern: String, in text: String) -> [NSTextCheckingResult] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        return regex.matches(in: text, range: NSRange(location: 0, length: (text as NSString).length))
    }
}

extension EditorModel {
    /// Anything already painted over, so a second scan does not list it again.
    fileprivate var coveredRects: [CGRect] {
        annotations.compactMap { item in
            guard case .shape(let mark) = item, mark.kind == .pixelate || mark.kind == .blur || mark.kind == .rectFill else { return nil }
            return normalized(CGRect(x: mark.x, y: mark.y, width: mark.w, height: mark.h))
        }
    }

    func copyText() {
        guard let picture else { return }
        let primary = picture.image
        let others = layers.dropFirst().sorted { $0.order < $1.order }.map(\.image)
        let visible = crop
        let hidden = coveredRects
        notice = "Reading text…"
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var parts = [TextScan.visibleText(TextScan.lines(in: primary), visible: visible, hidden: hidden)]
            parts += others.map { TextScan.visibleText(TextScan.lines(in: $0), visible: nil, hidden: []) }
            let text = parts.filter { !$0.isEmpty }.joined(separator: "\n\n")
            DispatchQueue.main.async {
                guard let self, self.picture?.image === primary else { return }
                guard !text.isEmpty else {
                    self.notice = "Shotli couldn't find any text in this picture."
                    return
                }
                let board = NSPasteboard.general
                board.clearContents()
                board.setString(text, forType: .string)
                let count = text.components(separatedBy: "\n").filter { !$0.isEmpty }.count
                self.notice = count == 1 ? "Copied 1 line of text" : "Copied \(count) lines of text"
            }
        }
    }

    func scanSensitive(_ finish: @escaping ([SensitiveFinding]) -> Void) {
        guard let picture else {
            finish([])
            return
        }
        let image = picture.image
        let covered = coveredRects
        let bounds = CGSize(width: picture.width, height: picture.height)
        DispatchQueue.global(qos: .userInitiated).async {
            let found = SensitiveText.findings(in: TextScan.lines(in: image), bounds: bounds, covered: covered)
            DispatchQueue.main.async { finish(found) }
        }
    }

    func hide(_ findings: [SensitiveFinding]) {
        guard !findings.isEmpty else { return }
        edit {
            annotations += findings.map { finding in
                // Blocks at least as tall as the text, so no letter keeps its shape.
                .shape(ShapeMark(
                    id: UUID().uuidString,
                    kind: .pixelate,
                    color: brush.color,
                    strokeWidth: brush.strokeWidth,
                    x: finding.rect.minX,
                    y: finding.rect.minY,
                    w: finding.rect.width,
                    h: finding.rect.height,
                    amount: max(14, finding.rect.height)
                ))
            }
            selectedID = nil
        }
        notice = findings.count == 1 ? "Hid 1 item" : "Hid \(findings.count) items"
    }
}

struct SensitivePopover: View {
    @ObservedObject var model: EditorModel
    @State private var scanning = true
    @State private var findings: [SensitiveFinding] = []
    @State private var skipped: Set<String> = []
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Hide Sensitive Info")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(ShotliGlass.ink(colorScheme))
            if scanning {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Reading the picture…")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            } else if findings.isEmpty {
                Text("Shotli didn't find any emails, phone numbers, card numbers, or keys.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(findings) { finding in
                            row(finding)
                        }
                    }
                }
                .frame(maxHeight: 220)
                Button(action: hideChosen) {
                    Text(chosen.count == 1 ? "Hide 1 item" : "Hide \(chosen.count) items")
                        .frame(maxWidth: .infinity)
                }
                .disabled(chosen.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
            if !scanning {
                Text(caveat)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(width: 300)
        .onAppear {
            model.scanSensitive { found in
                findings = found
                scanning = false
            }
        }
    }

    private var caveat: String {
        let base = "Shotli can miss things. Check the picture before you share it."
        return model.screenshotCount >= 2 ? "Only the first screenshot is checked. \(base)" : base
    }

    private var chosen: [SensitiveFinding] {
        findings.filter { !skipped.contains($0.id) }
    }

    private func row(_ finding: SensitiveFinding) -> some View {
        Toggle(isOn: Binding(
            get: { !skipped.contains(finding.id) },
            set: { on in
                if on { skipped.remove(finding.id) } else { skipped.insert(finding.id) }
            }
        )) {
            HStack(spacing: 6) {
                Image(systemName: finding.kind.symbol)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .frame(width: 16)
                VStack(alignment: .leading, spacing: 1) {
                    Text(finding.preview)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(ShotliGlass.ink(colorScheme))
                        .lineLimit(1)
                    Text(finding.kind.title)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
        }
        .accessibilityLabel(finding.kind.title)
    }

    private func hideChosen() {
        model.hide(chosen)
        model.showHideSensitive = false
    }
}
