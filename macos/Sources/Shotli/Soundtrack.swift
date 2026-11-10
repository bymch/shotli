import AVFoundation
import Foundation

/// Background music Shotli composes and renders itself, so every track is free to use anywhere.
enum Soundtrack: String, CaseIterable, Identifiable {
    case glow, pulse, lofi, bright

    var id: String { rawValue }

    var title: String {
        switch self {
        case .glow: return "Glow"
        case .pulse: return "Pulse"
        case .lofi: return "Lo-fi"
        case .bright: return "Bright"
        }
    }

    var detail: String {
        switch self {
        case .glow: return "Calm and airy"
        case .pulse: return "Upbeat electronic"
        case .lofi: return "Warm, laid back"
        case .bright: return "Light and happy"
        }
    }

    var symbol: String {
        switch self {
        case .glow: return "sparkles"
        case .pulse: return "bolt.fill"
        case .lofi: return "cup.and.saucer.fill"
        case .bright: return "sun.max.fill"
        }
    }

    /// Bump when a track's sound changes so cached files are replaced.
    static let version = 1
    static let sampleRate = 44_100.0
    /// Longer than the longest video, 8 seconds at half speed.
    static let minimumLength = 17.0

    var fileName: String { "\(rawValue)-\(Soundtrack.version).wav" }

    init?(file: URL) {
        guard let match = Soundtrack.allCases.first(where: { $0.fileName == file.lastPathComponent }) else { return nil }
        self = match
    }

    static var folder: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return caches.appendingPathComponent("Shotli/Music", isDirectory: true)
    }

    /// The rendered track on disk, made on first use.
    func url() throws -> URL {
        let url = Soundtrack.folder.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: url.path) { return url }
        try FileManager.default.createDirectory(at: Soundtrack.folder, withIntermediateDirectories: true)
        let temp = Soundtrack.folder.appendingPathComponent("\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: temp) }
        try Soundtrack.write(render(), to: temp)
        if !FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.moveItem(at: temp, to: url)
        }
        return url
    }

    func render() -> (left: [Float], right: [Float]) {
        switch self {
        case .glow: return Score.glow().master()
        case .pulse: return Score.pulse().master()
        case .lofi: return Score.lofi().master()
        case .bright: return Score.bright().master()
        }
    }

    static func write(_ audio: (left: [Float], right: [Float]), to url: URL) throws {
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 2,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ]
        let count = audio.left.count
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 2, interleaved: false),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count)),
              let channels = buffer.floatChannelData else {
            throw MotionExportError.writer("Couldn't make the music.")
        }
        buffer.frameLength = AVAudioFrameCount(count)
        for i in 0..<count {
            channels[0][i] = audio.left[i]
            channels[1][i] = audio.right[i]
        }
        let file = try AVAudioFile(forWriting: url, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false)
        try file.write(from: buffer)
    }
}

// MARK: - Scores

private enum Score {
    static func glow() -> Studio {
        let studio = Studio(bpm: 76, bars: 6)
        studio.echoBeats = 0.75
        let chords: [[Double]] = [
            [48, 55, 59, 62, 64],
            [45, 52, 55, 59, 60],
            [41, 48, 52, 55, 57],
            [43, 50, 55, 57, 62],
        ]
        let arp = [0, 2, 1, 3, 2, 0, 3, 1]
        for bar in 0..<studio.bars {
            let chord = chords[bar % chords.count]
            let start = studio.time(bar, 0)
            let hold = studio.barLength + 0.2
            for (k, note) in chord.dropFirst().enumerated() {
                let pan = Float(k) / 3 * 0.8 - 0.4
                studio.place(Voice.pad(Studio.hz(note), hold: hold, cutoff: 1300, attack: 0.7, release: 1.2),
                             at: start, gain: 0.15, pan: pan, verb: 0.55, ducked: false)
            }
            studio.place(Voice.bass(Studio.hz(chord[0] - 12), hold: studio.barLength * 0.92, drive: 0.8),
                         at: start, gain: 0.34, verb: 0.05, ducked: false)
            let tones = chord.dropFirst().map { $0 + 12 }
            for step in 0..<8 {
                let note = tones[arp[step] % tones.count]
                let accent: Float = step % 4 == 0 ? 1 : 0.7
                let pan = Float(sin(Double(bar * 8 + step) * 0.7)) * 0.5
                studio.place(Voice.bell(Studio.hz(note), decay: 1.4),
                             at: studio.time(bar, Double(step) * 0.5), gain: 0.085 * accent, pan: pan, verb: 0.5, echo: 0.3, ducked: false)
            }
        }
        return studio
    }

    static func pulse() -> Studio {
        let studio = Studio(bpm: 120, bars: 9)
        studio.echoBeats = 0.75
        let roots: [Double] = [45, 41, 48, 43]
        let chords: [[Double]] = [[57, 60, 64], [57, 60, 65], [55, 60, 64], [55, 59, 62]]
        let arp = [0, 1, 2, 3, 2, 1, 2, 1]
        for bar in 0..<studio.bars {
            let chord = chords[bar % chords.count]
            let root = roots[bar % roots.count]
            for beat in 0..<4 {
                let at = studio.time(bar, Double(beat))
                studio.place(Voice.kick(), at: at, gain: 0.9, ducked: false)
                studio.sidechain(at: at, depth: 0.6)
                if beat % 2 == 1 {
                    studio.place(Voice.clap(&studio.noise), at: at, gain: 0.32, verb: 0.2, ducked: false)
                }
                studio.place(Voice.hat(&studio.noise), at: studio.time(bar, Double(beat) + 0.5), gain: 0.2, pan: 0.25, ducked: false)
                studio.place(Voice.hat(&studio.noise, decay: 0.02), at: studio.time(bar, Double(beat) + 0.25), gain: 0.06, pan: -0.2, ducked: false)
                studio.place(Voice.hat(&studio.noise, decay: 0.02), at: studio.time(bar, Double(beat) + 0.75), gain: 0.06, pan: -0.2, ducked: false)
                studio.place(Voice.bass(Studio.hz(root - 12), hold: studio.beat * 0.4, drive: 2.2),
                             at: studio.time(bar, Double(beat) + 0.5), gain: 0.3)
            }
            for note in chord {
                studio.place(Voice.pad(Studio.hz(note), hold: studio.barLength, cutoff: 2200, attack: 0.05, release: 0.3),
                             at: studio.time(bar, 0), gain: 0.12, pan: Float(note - 60) * 0.06, verb: 0.3)
            }
            let tones = chord.map { $0 + 12 } + [chord[0] + 24]
            for step in 0..<8 {
                let note = tones[arp[step]]
                studio.place(Voice.pluck(Studio.hz(note), hold: studio.beat * 0.45, noise: &studio.noise),
                             at: studio.time(bar, Double(step) * 0.5), gain: 0.13, pan: step % 2 == 0 ? -0.3 : 0.3, verb: 0.2, echo: 0.35)
            }
        }
        return studio
    }

    static func lofi() -> Studio {
        let studio = Studio(bpm: 80, bars: 6)
        studio.echoBeats = 0.5
        studio.masterCutoff = 4500
        let roots: [Double] = [38, 43, 36, 45]
        let chords: [[Double]] = [[53, 57, 60, 64], [53, 57, 59, 64], [52, 55, 59, 62], [55, 58, 61, 64]]
        let swing = 0.08
        for bar in 0..<studio.bars {
            let chord = chords[bar % chords.count]
            let root = roots[bar % roots.count]
            for (k, note) in chord.enumerated() {
                let pan = Float(k) * 0.15 - 0.22
                studio.place(Voice.keys(Studio.hz(note), hold: studio.beat * 1.6),
                             at: studio.time(bar, 0) + Double(k) * 0.014, gain: 0.12, pan: pan, verb: 0.35)
                studio.place(Voice.keys(Studio.hz(note), hold: studio.beat * 1.2),
                             at: studio.time(bar, 2.5 + swing) + Double(k) * 0.012, gain: 0.075, pan: pan, verb: 0.35)
            }
            studio.place(Voice.bass(Studio.hz(root), hold: studio.beat * 1.4, drive: 1.2),
                         at: studio.time(bar, 0), gain: 0.32, ducked: false)
            studio.place(Voice.bass(Studio.hz(root), hold: studio.beat * 0.9, drive: 1.2),
                         at: studio.time(bar, 2.5 + swing), gain: 0.26, ducked: false)
            studio.place(Voice.kick(tone: 0.8), at: studio.time(bar, 0), gain: 0.75, ducked: false)
            studio.place(Voice.kick(tone: 0.8), at: studio.time(bar, 2.5 + swing), gain: 0.6, ducked: false)
            studio.place(Voice.snare(&studio.noise), at: studio.time(bar, 1), gain: 0.36, verb: 0.15, ducked: false)
            studio.place(Voice.snare(&studio.noise), at: studio.time(bar, 3), gain: 0.36, verb: 0.15, ducked: false)
            for eighth in 0..<8 {
                let offbeat = eighth % 2 == 1
                let beat = Double(eighth) * 0.5 + (offbeat ? swing : 0)
                studio.place(Voice.hat(&studio.noise, decay: 0.03), at: studio.time(bar, beat), gain: offbeat ? 0.07 : 0.11, pan: 0.2, ducked: false)
            }
        }
        studio.crackle(rate: 7, gain: 0.05, hiss: 0.004)
        return studio
    }

    static func bright() -> Studio {
        let studio = Studio(bpm: 112, bars: 8)
        studio.echoBeats = 0.75
        let roots: [Double] = [38, 33, 35, 31]
        let chords: [[Double]] = [[62, 66, 69, 74], [61, 64, 69, 73], [62, 66, 71, 74], [62, 67, 71, 74]]
        let arp = [0, 1, 2, 3, 2, 1, 2, 3]
        let melody: [(beat: Double, tone: Int)] = [(0, 3), (1.5, 1), (2, 2), (3, 3)]
        for bar in 0..<studio.bars {
            let chord = chords[bar % chords.count]
            let root = roots[bar % roots.count]
            for step in 0..<8 {
                studio.place(Voice.pluck(Studio.hz(chord[arp[step]]), hold: studio.beat * 0.45, noise: &studio.noise, bright: 0.65),
                             at: studio.time(bar, Double(step) * 0.5), gain: 0.12, pan: step % 2 == 0 ? -0.35 : 0.35, verb: 0.25, echo: 0.25)
                studio.place(Voice.shaker(&studio.noise), at: studio.time(bar, Double(step) * 0.5),
                             gain: step % 2 == 1 ? 0.1 : 0.06, pan: 0.3, ducked: false)
            }
            for hit in melody {
                studio.place(Voice.mallet(Studio.hz(chord[hit.tone] + 12)), at: studio.time(bar, hit.beat),
                             gain: 0.1, pan: -0.1, verb: 0.3, echo: 0.15)
            }
            for note in chord.prefix(3) {
                studio.place(Voice.pad(Studio.hz(note - 12), hold: studio.barLength, cutoff: 1800, attack: 0.2, release: 0.5),
                             at: studio.time(bar, 0), gain: 0.06, verb: 0.4)
            }
            for beat in [0.0, 1.5, 2.0, 3.0] {
                studio.place(Voice.bass(Studio.hz(root), hold: studio.beat * 0.4, drive: 1.5), at: studio.time(bar, beat), gain: 0.3)
            }
            for beat in [0.0, 2.0] {
                studio.place(Voice.kick(), at: studio.time(bar, beat), gain: 0.7, ducked: false)
                studio.sidechain(at: studio.time(bar, beat), depth: 0.3)
            }
            for beat in [1.0, 3.0] {
                studio.place(Voice.clap(&studio.noise), at: studio.time(bar, beat), gain: 0.24, verb: 0.2, ducked: false)
            }
        }
        return studio
    }
}

// MARK: - Studio

/// A small mixer: buses, a ducked music bus, a ping-pong echo, a plate-style reverb, and a soft limiter.
private final class Studio {
    static let rate = Soundtrack.sampleRate

    let beat: Double
    let bars: Int
    let count: Int
    var echoBeats = 0.75
    var masterCutoff: Double?
    var noise = Noise(seed: 0x5107_5107)

    private var drumsL: [Float]
    private var drumsR: [Float]
    private var musicL: [Float]
    private var musicR: [Float]
    private var verbSend: [Float]
    private var echoSend: [Float]
    private var duck: [Float]

    var barLength: Double { beat * 4 }

    init(bpm: Double, bars: Int) {
        beat = 60 / bpm
        self.bars = bars
        count = Int((Double(bars) * 4 * beat * Studio.rate).rounded())
        drumsL = [Float](repeating: 0, count: count)
        drumsR = drumsL
        musicL = drumsL
        musicR = drumsL
        verbSend = drumsL
        echoSend = drumsL
        duck = [Float](repeating: 1, count: count)
    }

    static func hz(_ midi: Double) -> Double { 440 * pow(2, (midi - 69) / 12) }

    func time(_ bar: Int, _ beatInBar: Double) -> Double { (Double(bar) * 4 + beatInBar) * beat }

    func place(_ samples: [Float], at time: Double, gain: Float, pan: Float = 0,
               verb: Float = 0, echo: Float = 0, ducked: Bool = true) {
        let start = Int(time * Studio.rate)
        let angle = Double(max(-1, min(1, pan)) + 1) * .pi / 4
        let left = gain * Float(cos(angle))
        let right = gain * Float(sin(angle))
        for (i, x) in samples.enumerated() {
            let at = start + i
            if at < 0 { continue }
            if at >= count { break }
            if ducked {
                musicL[at] += x * left
                musicR[at] += x * right
            } else {
                drumsL[at] += x * left
                drumsR[at] += x * right
            }
            verbSend[at] += x * gain * verb
            echoSend[at] += x * gain * echo
        }
    }

    /// Dips the music bus under a kick, the pumping sound of dance tracks.
    func sidechain(at time: Double, depth: Float) {
        let start = Int(time * Studio.rate)
        let span = Int(0.4 * Studio.rate)
        for i in 0..<span {
            let at = start + i
            if at < 0 { continue }
            if at >= count { break }
            let t = Double(i) / Studio.rate
            let dip = t < 0.006 ? Float(t / 0.006) : Float(exp(-(t - 0.006) / 0.11))
            duck[at] = min(duck[at], 1 - depth * dip)
        }
    }

    /// Vinyl clicks and a little hiss.
    func crackle(rate perSecond: Double, gain: Float, hiss: Float) {
        for i in 0..<count {
            let h = noise.next() * hiss
            drumsL[i] += h
            drumsR[i] += noise.next() * hiss
            if Double(abs(noise.next())) < perSecond / Studio.rate {
                let size = gain * (0.3 + abs(noise.next()))
                let side = noise.next() > 0
                for k in 0..<40 where i + k < count {
                    let click = size * Float(exp(-Double(k) / 6)) * (k % 2 == 0 ? 1 : -0.6)
                    if side { drumsL[i + k] += click } else { drumsR[i + k] += click }
                }
            }
        }
    }

    func master() -> (left: [Float], right: [Float]) {
        let echo = pingPong()
        let room = reverb()
        var left = [Float](repeating: 0, count: count)
        var right = left
        var lowL: Float = 0
        var lowR: Float = 0
        let tone = masterCutoff.map { Float(1 - exp(-2 * .pi * $0 / Studio.rate)) }
        for i in 0..<count {
            var l = drumsL[i] + musicL[i] * duck[i] + echo.left[i] * 0.55 + room.left[i]
            var r = drumsR[i] + musicR[i] * duck[i] + echo.right[i] * 0.55 + room.right[i]
            if let tone {
                lowL += tone * (l - lowL)
                lowR += tone * (r - lowR)
                l = lowL
                r = lowR
            }
            left[i] = l
            right[i] = r
        }
        var peak: Float = 0.0001
        for i in 0..<count { peak = max(peak, abs(left[i]), abs(right[i])) }
        let drive: Float = 1.6
        let scale = drive / peak
        let ceiling: Float = 0.89 / tanhf(drive)
        let fade = Int(0.005 * Studio.rate)
        for i in 0..<count {
            let edge: Float = i < fade ? Float(i) / Float(fade) : 1
            left[i] = tanhf(left[i] * scale) * ceiling * edge
            right[i] = tanhf(right[i] * scale) * ceiling * edge
        }
        return (left, right)
    }

    private func pingPong() -> (left: [Float], right: [Float]) {
        let delay = max(1, Int(echoBeats * beat * Studio.rate))
        var lineL = [Float](repeating: 0, count: delay)
        var lineR = lineL
        var outL = [Float](repeating: 0, count: count)
        var outR = outL
        var lowL: Float = 0
        var lowR: Float = 0
        var pos = 0
        for i in 0..<count {
            let oL = lineL[pos]
            let oR = lineR[pos]
            lowL += 0.35 * (oL - lowL)
            lowR += 0.35 * (oR - lowR)
            lineL[pos] = echoSend[i] + lowR * 0.42
            lineR[pos] = lowL
            outL[i] = oL
            outR[i] = oR
            pos += 1
            if pos == delay { pos = 0 }
        }
        return (outL, outR)
    }

    /// Freeverb's comb and allpass layout.
    private func reverb() -> (left: [Float], right: [Float]) {
        let scale = Studio.rate / 44_100
        let combs = [1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617]
        let passes = [556, 441, 341, 225]
        func channel(spread: Int) -> [Float] {
            var combLines = combs.map { Comb(length: Int(Double($0 + spread) * scale)) }
            var passLines = passes.map { AllPass(length: Int(Double($0 + spread) * scale)) }
            var out = [Float](repeating: 0, count: count)
            for i in 0..<count {
                let x = verbSend[i] * 0.06
                var sum: Float = 0
                for k in 0..<combLines.count { sum += combLines[k].process(x) }
                for k in 0..<passLines.count { sum = passLines[k].process(sum) }
                out[i] = sum
            }
            return out
        }
        return (channel(spread: 0), channel(spread: 23))
    }
}

private struct Comb {
    var line: [Float]
    var pos = 0
    var store: Float = 0
    let feedback: Float = 0.84
    let damp: Float = 0.25

    init(length: Int) { line = [Float](repeating: 0, count: max(1, length)) }

    mutating func process(_ x: Float) -> Float {
        let y = line[pos]
        store = y * (1 - damp) + store * damp
        line[pos] = x + store * feedback
        pos += 1
        if pos == line.count { pos = 0 }
        return y
    }
}

private struct AllPass {
    var line: [Float]
    var pos = 0

    init(length: Int) { line = [Float](repeating: 0, count: max(1, length)) }

    mutating func process(_ x: Float) -> Float {
        let b = line[pos]
        line[pos] = x + b * 0.5
        pos += 1
        if pos == line.count { pos = 0 }
        return b - x
    }
}

private struct Noise {
    var state: UInt64

    init(seed: UInt64) { state = seed }

    /// White noise in -1...1, the same every render.
    mutating func next() -> Float {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return Float(Double(state >> 11) / Double(1 << 53)) * 2 - 1
    }
}

// MARK: - Voices

private enum Voice {
    static let rate = Soundtrack.sampleRate

    private static func blep(_ t: Double, _ dt: Double) -> Double {
        if t < dt {
            let x = t / dt
            return x + x - x * x - 1
        }
        if t > 1 - dt {
            let x = (t - 1) / dt
            return x * x + x + x + 1
        }
        return 0
    }

    private static func gate(_ t: Double, attack: Double, hold: Double, release: Double) -> Double {
        var level = 1.0
        if t < attack {
            let x = t / attack
            level = x * x * (3 - 2 * x)
        }
        if t > hold {
            let r = min(1, (t - hold) / release)
            level *= (1 - r) * (1 - r)
        }
        return level
    }

    /// Three detuned saws through a soft low-pass.
    static func pad(_ f: Double, hold: Double, cutoff: Double, attack: Double, release: Double) -> [Float] {
        let count = Int((hold + release) * rate)
        var out = [Float](repeating: 0, count: count)
        let detune = [0.9965, 1.0, 1.0035]
        var phases = [0.13, 0.57, 0.81]
        var low1 = 0.0
        var low2 = 0.0
        let a = 1 - exp(-2 * .pi * cutoff / rate)
        for i in 0..<count {
            var x = 0.0
            for k in 0..<3 {
                let dt = f * detune[k] / rate
                var p = phases[k] + dt
                if p >= 1 { p -= 1 }
                phases[k] = p
                x += 2 * p - 1 - blep(p, dt)
            }
            low1 += a * (x / 3 - low1)
            low2 += a * (low1 - low2)
            out[i] = Float(low2 * gate(Double(i) / rate, attack: attack, hold: hold, release: release))
        }
        return out
    }

    /// An FM electric piano.
    static func keys(_ f: Double, hold: Double) -> [Float] {
        let release = 0.3
        let count = Int((hold + release) * rate)
        var out = [Float](repeating: 0, count: count)
        let w = 2 * .pi * f / rate
        for i in 0..<count {
            let t = Double(i) / rate
            let index = 1.5 * exp(-t / 0.3) + 0.12
            let wobble = 1 + 0.0015 * sin(2 * .pi * 0.4 * t)
            let x = sin(w * Double(i) * wobble + index * sin(w * Double(i))) + 0.08 * sin(w * 14 * Double(i)) * exp(-t / 0.015)
            let body = t < 0.004 ? t / 0.004 : exp(-t / 1.8)
            out[i] = Float(x * body * gate(t, attack: 0, hold: hold, release: release))
        }
        return out
    }

    /// Karplus-Strong string with an allpass for exact pitch.
    static func pluck(_ f: Double, hold: Double, noise: inout Noise, bright: Double = 0.5) -> [Float] {
        let release = 0.25
        var total = rate / f - 0.5
        if total < 2.2 { total = 2.2 }
        var length = Int(total)
        var frac = total - Double(length)
        if frac < 0.2 {
            length -= 1
            frac += 1
        }
        let c = Float((1 - frac) / (1 + frac))
        var line = [Float](repeating: 0, count: length)
        var smooth: Float = 0
        for k in 0..<length {
            smooth += Float(bright) * (noise.next() - smooth)
            line[k] = smooth
        }
        let count = Int((hold + release) * rate)
        var out = [Float](repeating: 0, count: count)
        var pos = 0
        var previous: Float = 0
        var x1: Float = 0
        var y1: Float = 0
        for i in 0..<count {
            let y = line[pos]
            let average = 0.996 * 0.5 * (y + previous)
            previous = y
            let tuned = c * average + x1 - c * y1
            x1 = average
            y1 = tuned
            line[pos] = tuned
            pos += 1
            if pos == length { pos = 0 }
            out[i] = y * Float(gate(Double(i) / rate, attack: 0, hold: hold, release: release)) * 1.6
        }
        return out
    }

    static func bell(_ f: Double, decay: Double) -> [Float] {
        let count = Int(decay * 4 * rate)
        var out = [Float](repeating: 0, count: count)
        let w = 2 * .pi * f / rate
        for i in 0..<count {
            let t = Double(i) / rate
            let attack = min(1, t / 0.003)
            let x = sin(w * Double(i)) * exp(-t / decay)
                + 0.25 * sin(2 * w * Double(i)) * exp(-t / (decay * 0.5))
                + 0.1 * sin(5.4 * w * Double(i)) * exp(-t / 0.08)
            out[i] = Float(x * attack)
        }
        return out
    }

    static func mallet(_ f: Double) -> [Float] {
        let count = Int(0.9 * rate)
        var out = [Float](repeating: 0, count: count)
        let w = 2 * .pi * f / rate
        for i in 0..<count {
            let t = Double(i) / rate
            let attack = min(1, t / 0.002)
            let x = sin(w * Double(i)) * exp(-t / 0.28) + 0.3 * sin(3.98 * w * Double(i)) * exp(-t / 0.04)
            out[i] = Float(x * attack)
        }
        return out
    }

    static func bass(_ f: Double, hold: Double, drive: Double) -> [Float] {
        let release = 0.08
        let count = Int((hold + release) * rate)
        var out = [Float](repeating: 0, count: count)
        let w = 2 * .pi * f / rate
        let norm = tanh(max(0.3, drive))
        for i in 0..<count {
            let x = sin(w * Double(i)) + 0.3 * sin(2 * w * Double(i))
            let shaped = tanh(max(0.3, drive) * x) / norm
            out[i] = Float(shaped * gate(Double(i) / rate, attack: 0.004, hold: hold, release: release))
        }
        return out
    }

    static func kick(tone: Double = 1) -> [Float] {
        let count = Int(0.45 * rate)
        var out = [Float](repeating: 0, count: count)
        var phase = 0.0
        for i in 0..<count {
            let t = Double(i) / rate
            phase += 2 * .pi * (46 + 110 * tone * exp(-t / 0.032)) / rate
            let body = sin(phase) * exp(-t / 0.3)
            let click = sin(phase * 7) * exp(-t / 0.003) * 0.25
            out[i] = Float(tanh(1.4 * (body + click)) * min(1, t / 0.001))
        }
        return out
    }

    static func snare(_ noise: inout Noise) -> [Float] {
        let count = Int(0.35 * rate)
        var out = [Float](repeating: 0, count: count)
        var low: Float = 0
        let a = Float(1 - exp(-2 * .pi * 1500 / rate))
        for i in 0..<count {
            let t = Double(i) / rate
            let n = noise.next()
            low += a * (n - low)
            let hiss = (n - low) * Float(exp(-t / 0.12))
            let body = Float(sin(2 * .pi * 185 * t) * exp(-t / 0.06)) * 0.6
            out[i] = (hiss + body) * Float(min(1, t / 0.001))
        }
        return out
    }

    static func clap(_ noise: inout Noise) -> [Float] {
        let count = Int(0.4 * rate)
        var out = [Float](repeating: 0, count: count)
        var low: Float = 0
        var high: Float = 0
        let a = Float(1 - exp(-2 * .pi * 900 / rate))
        let b = Float(1 - exp(-2 * .pi * 5000 / rate))
        for i in 0..<count {
            let t = Double(i) / rate
            var env = 0.0
            for burst in [0.0, 0.011, 0.022] where t >= burst {
                env = max(env, exp(-(t - burst) / 0.006))
            }
            if t >= 0.022 { env = max(env, 0.6 * exp(-(t - 0.022) / 0.12)) }
            let n = noise.next()
            low += a * (n - low)
            high += b * ((n - low) - high)
            out[i] = high * Float(env) * 2
        }
        return out
    }

    static func hat(_ noise: inout Noise, decay: Double = 0.035) -> [Float] {
        let count = Int(min(0.2, decay * 5) * rate)
        var out = [Float](repeating: 0, count: count)
        var low1: Float = 0
        var low2: Float = 0
        let a = Float(1 - exp(-2 * .pi * 7000 / rate))
        for i in 0..<count {
            let t = Double(i) / rate
            let n = noise.next()
            low1 += a * (n - low1)
            let h = n - low1
            low2 += a * (h - low2)
            out[i] = (h - low2) * Float(exp(-t / decay))
        }
        return out
    }

    static func shaker(_ noise: inout Noise) -> [Float] {
        let count = Int(0.2 * rate)
        var out = [Float](repeating: 0, count: count)
        var low: Float = 0
        let a = Float(1 - exp(-2 * .pi * 5000 / rate))
        for i in 0..<count {
            let t = Double(i) / rate
            let n = noise.next()
            low += a * (n - low)
            let env = t < 0.012 ? t / 0.012 : exp(-(t - 0.012) / 0.05)
            out[i] = (n - low) * Float(env)
        }
        return out
    }
}
