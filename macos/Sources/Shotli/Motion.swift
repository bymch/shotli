import CoreGraphics
import Foundation

enum MotionPreset: String, CaseIterable, Identifiable {
    case float, perspective, focus, drift, orbit, reveal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .float: return "Float"
        case .perspective: return "Perspective"
        case .focus: return "Focus"
        case .drift: return "Drift"
        case .orbit: return "Orbit"
        case .reveal: return "Reveal"
        }
    }

    var detail: String {
        switch self {
        case .float: return "Rises, tilts a little, and the shadow softens."
        case .perspective: return "A shallow turn. The picture stays readable."
        case .focus: return "Moves closer, then back to the same scale."
        case .drift: return "Glides across. The background can follow."
        case .orbit: return "Travels around the middle of the frame."
        case .reveal: return "Enters on a rise. It can leave again."
        }
    }
}

struct MotionSettings: Equatable {
    var preset: MotionPreset = .float
    var duration: Double = 4
    var speed: Double = 1
    var intensity: Double = 0.7
    var rotation: Double = 0.45
    var zoom: Double = 0.6
    var perspective: Double = 0.5
    var shadow: Double = 0.6
    var background: Double = 0.45
    var loops: Bool = true
    var entrance: Bool = true
    var exit: Bool = true
    var music: URL?

    var clampedDuration: Double { min(8, max(2, duration)) }
    var clampedSpeed: Double { min(2, max(0.5, speed)) }
    /// One full cycle. Speed shortens or lengthens the file without changing the path.
    var outputDuration: Double { clampedDuration / clampedSpeed }
}

struct MotionSample: Equatable {
    var angle: CGFloat
    var lift: CGFloat
    var sway: CGFloat
}

struct MotionPose: Equatable {
    var shiftX: CGFloat = 0
    var shiftY: CGFloat = 0
    var scale: CGFloat = 1
    var rotation: CGFloat = 0
    var tiltX: CGFloat = 0
    var tiltY: CGFloat = 0
    var shadowGain: CGFloat = 1
    var parallaxX: CGFloat = 0
    var parallaxY: CGFloat = 0
    var opacity: CGFloat = 1
}

enum MotionTimeline {
    static func progress(time: Double, span: Double, loops: Bool) -> CGFloat {
        let safe = max(0.2, span)
        if loops {
            let turns = time / safe
            return CGFloat(turns - floor(turns))
        }
        return CGFloat(min(1, max(0, time / safe)))
    }

    static func pose(settings: MotionSettings, time: Double) -> MotionPose {
        let span = settings.outputDuration
        let loops = settings.loops
        let u = progress(time: time, span: span, loops: loops)
        let angle = (loops ? u : u) * (loops ? 2 * .pi : .pi)
        let lift: CGFloat = loops ? (1 - cos(angle)) / 2 : sin(angle)
        let sway = sin(angle)
        let sample = MotionSample(angle: angle, lift: lift, sway: sway)
        var pose = base(settings.preset, sample: sample, settings: settings, progress: u)
        if settings.preset != .reveal, !loops, settings.entrance || settings.exit {
            let gate = edge(u, entrance: settings.entrance, exit: settings.exit)
            pose = scaled(pose, by: gate)
        }
        return pose
    }

    private static func base(_ preset: MotionPreset, sample: MotionSample, settings: MotionSettings, progress: CGFloat) -> MotionPose {
        let move = unit(settings.intensity)
        let spin = unit(settings.rotation)
        let zoom = unit(settings.zoom)
        let depth = unit(settings.perspective)
        let shade = unit(settings.shadow)
        let drift = unit(settings.background)
        var pose = MotionPose()
        switch preset {
        case .float:
            pose.shiftY = sample.sway * 0.034 * move
            pose.rotation = sample.sway * 2.6 * spin
            pose.shadowGain = 1 + abs(sample.sway) * 0.65 * shade
        case .perspective:
            pose.tiltY = sample.sway * 8 * depth
            pose.tiltX = sin(sample.angle * 2) * 2.6 * depth
            pose.scale = 1 - (1 - cos(sample.angle)) * 0.02 * zoom
            pose.shadowGain = 1 + abs(sample.sway) * 0.28 * shade
        case .focus:
            pose.scale = 1 + sample.lift * 0.09 * zoom
            pose.shadowGain = 1 + sample.lift * 0.2 * shade
        case .drift:
            pose.shiftX = sample.sway * 0.042 * move
            pose.shiftY = sin(sample.angle * 2) * 0.02 * move
            pose.parallaxX = -pose.shiftX * drift
            pose.parallaxY = -pose.shiftY * drift
            pose.shadowGain = 1 + abs(sample.sway) * 0.2 * shade
        case .orbit:
            pose.shiftX = sample.sway * 0.03 * move
            pose.shiftY = (cos(sample.angle) - 1) * 0.02 * move
            pose.rotation = sample.sway * 5 * spin
            pose.tiltY = sample.sway * 5 * depth
            pose.tiltX = (1 - cos(sample.angle)) * 1.6 * depth
            pose.shadowGain = 1 + abs(sample.sway) * 0.22 * shade
        case .reveal:
            let shown = reveal(progress, loops: settings.loops, entrance: settings.entrance, exit: settings.exit)
            pose.opacity = shown
            pose.scale = 1 - (1 - shown) * 0.08 * max(zoom, 0.35)
            pose.shiftY = (1 - shown) * 0.05 * max(move, 0.35)
            pose.shadowGain = 0.35 + shown * 0.65 * shade
        }
        return pose
    }

    private static func reveal(_ u: CGFloat, loops: Bool, entrance: Bool, exit: Bool) -> CGFloat {
        let inEnd: CGFloat = 0.28
        let outStart: CGFloat = 0.72
        if loops {
            if u < inEnd { return smooth(u / inEnd) }
            if u > outStart { return smooth((1 - u) / (1 - outStart)) }
            return 1
        }
        var shown: CGFloat = 1
        if entrance, u < inEnd { shown = smooth(u / inEnd) }
        if exit, u > outStart { shown = min(shown, smooth((1 - u) / (1 - outStart))) }
        return shown
    }

    private static func edge(_ u: CGFloat, entrance: Bool, exit: Bool) -> CGFloat {
        var gate: CGFloat = 1
        if entrance, u < 0.22 { gate = smooth(u / 0.22) }
        if exit, u > 0.78 { gate = min(gate, smooth((1 - u) / 0.22)) }
        return gate
    }

    private static func scaled(_ pose: MotionPose, by gate: CGFloat) -> MotionPose {
        var pose = pose
        pose.shiftX *= gate
        pose.shiftY *= gate
        pose.rotation *= gate
        pose.tiltX *= gate
        pose.tiltY *= gate
        pose.parallaxX *= gate
        pose.parallaxY *= gate
        pose.scale = 1 + (pose.scale - 1) * gate
        pose.shadowGain = 1 + (pose.shadowGain - 1) * gate
        return pose
    }

    private static func smooth(_ value: CGFloat) -> CGFloat {
        let u = min(1, max(0, value))
        return u * u * (3 - 2 * u)
    }

    private static func unit(_ value: Double) -> CGFloat {
        CGFloat(min(1, max(0, value)))
    }
}

enum MotionFormat {
    static let exportSize = CGSize(width: 1920, height: 1080)
    static let previewSize = CGSize(width: 1280, height: 720)
    static let fps = 30
    static let bleed: CGFloat = 80
}
