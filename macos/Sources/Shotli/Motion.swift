import CoreGraphics
import Foundation

enum MotionPreset: String, CaseIterable, Identifiable {
    case float
    case perspective
    case focus
    case drift

    var id: String { rawValue }

    var title: String {
        switch self {
        case .float: return "Float"
        case .perspective: return "Perspective"
        case .focus: return "Focus"
        case .drift: return "Drift"
        }
    }

    var detail: String {
        switch self {
        case .float: return "A slow rise, a slight tilt, and a softer shadow."
        case .perspective: return "A shallow turn that keeps the picture readable."
        case .focus: return "Moves closer, then returns to the same scale."
        case .drift: return "Glides across the frame. The background follows a little."
        }
    }
}

struct MotionSettings: Equatable {
    var preset: MotionPreset = .float
    var duration: Double = 4
    var intensity: Double = 0.62
    var loops: Bool = true

    var clampedDuration: Double { min(8, max(2, duration)) }
    var clampedIntensity: Double { min(1, max(0, intensity)) }
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
}

enum MotionTimeline {
    static func sample(time: Double, duration: Double, loops: Bool) -> MotionSample {
        let span = max(0.4, duration)
        if loops {
            let turns = time / span
            let frac = turns - floor(turns)
            let angle = CGFloat(frac) * 2 * .pi
            return MotionSample(angle: angle, lift: (1 - cos(angle)) / 2, sway: sin(angle))
        }
        let u = CGFloat(min(1, max(0, time / span)))
        let angle = u * .pi
        return MotionSample(angle: angle, lift: sin(angle), sway: sin(angle))
    }

    static func pose(preset: MotionPreset, sample: MotionSample, intensity: Double) -> MotionPose {
        let amount = CGFloat(min(1, max(0, intensity)))
        switch preset {
        case .float:
            var pose = MotionPose()
            pose.shiftY = sample.sway * 0.032 * amount
            pose.rotation = sample.sway * 1.15 * amount
            pose.shadowGain = 1 + abs(sample.sway) * 0.55 * amount
            return pose
        case .perspective:
            var pose = MotionPose()
            pose.tiltY = sample.sway * 7 * amount
            pose.tiltX = sin(sample.angle * 2) * 2.4 * amount
            pose.scale = 1 - (1 - cos(sample.angle)) * 0.015 * amount
            pose.shadowGain = 1 + abs(sample.sway) * 0.22 * amount
            return pose
        case .focus:
            var pose = MotionPose()
            pose.scale = 1 + sample.lift * 0.075 * amount
            return pose
        case .drift:
            var pose = MotionPose()
            let bob = sin(sample.angle * 2)
            pose.shiftX = sample.sway * 0.04 * amount
            pose.shiftY = bob * 0.018 * amount
            pose.parallaxX = -pose.shiftX * 0.55
            pose.parallaxY = -pose.shiftY * 0.55
            return pose
        }
    }

    static func pose(settings: MotionSettings, time: Double) -> MotionPose {
        let duration = settings.clampedDuration
        let sample = sample(time: time, duration: duration, loops: settings.loops)
        return pose(preset: settings.preset, sample: sample, intensity: settings.clampedIntensity)
    }
}

enum MotionFormat {
    static let exportSize = CGSize(width: 1920, height: 1080)
    static let previewSize = CGSize(width: 1280, height: 720)
    static let fps = 30
    static let bleed: CGFloat = 80
}
