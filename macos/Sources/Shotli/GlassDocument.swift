import AppKit
import SwiftUI

/// How a glass document is drawn. Thumbnail, fold, edge, and shadow can change independently.
struct GlassDocumentStyle: Equatable {
    var foldFraction: CGFloat = 0.28
    var radiusFraction: CGFloat = 0.075
    var veil: Double = 0.12
    var shadowOpacity: Double = 0.16
    var shadowRadius: CGFloat = 16
    var shadowY: CGFloat = 9
    var showsFold: Bool = true
    var showsEdge: Bool = true

    static let standard = GlassDocumentStyle()
    static let compact = GlassDocumentStyle(
        foldFraction: 0.26,
        radiusFraction: 0.1,
        veil: 0.16,
        shadowOpacity: 0.12,
        shadowRadius: 8,
        shadowY: 4
    )
}

/// A frosted document page. The thumbnail sits behind the glass. The folded corner is part of the outline.
struct GlassDocumentIcon: View {
    var image: NSImage?
    var frost: NSImage?
    var tint: Color = GlassDocumentIcon.neutral
    var style: GlassDocumentStyle = .standard
    var lifted: Bool = false
    var selected: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    static let neutral = Color(nsColor: NSColor(srgbRed: 0.80, green: 0.84, blue: 0.91, alpha: 1))

    var body: some View {
        Color.clear
            .aspectRatio(0.76, contentMode: .fit)
            .overlay(
                GeometryReader { geo in
                    let geometry = GlassDocumentGeometry(rect: CGRect(origin: .zero, size: geo.size), style: style)
                    document(geometry)
                }
            )
            .scaleEffect(lifted && !reduceMotion ? (style.shadowRadius < 12 ? 1.02 : 1.035) : 1, anchor: .center)
            .offset(y: lifted && !reduceMotion ? (style.shadowRadius < 12 ? -2 : -5) : 0)
            .animation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.74), value: lifted)
            .accessibilityHidden(true)
    }

    private func document(_ geometry: GlassDocumentGeometry) -> some View {
        let page = GlassDocumentPage(geometry: geometry)
        let shadowOpacity = style.shadowOpacity + (lifted ? 0.08 : 0)
        let shadowRadius = style.shadowRadius + (lifted ? 6 : 0)
        let shadowY = style.shadowY + (lifted ? 4 : 0)
        return ZStack {
            page.fill(tint.opacity(reduceTransparency ? 0.92 : 0.55))
            artwork(in: geometry.rect)
            page.fill(veil)
            page.fill(sheen)
            if style.showsFold {
                flap(geometry)
                crease(geometry)
            }
            if style.showsEdge {
                page.stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(lifted ? 0.95 : 0.82),
                            Color.white.opacity(0.28),
                            Color.white.opacity(0.62),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.15
                )
                page.stroke(Color.black.opacity(0.08), lineWidth: 0.6)
            }
            if selected {
                page.stroke(ShotliGlass.accent, lineWidth: 2.25)
            }
        }
        .compositingGroup()
        .shadow(color: Color.black.opacity(shadowOpacity), radius: shadowRadius, y: shadowY)
        .shadow(color: tint.opacity(lifted ? 0.22 : 0.08), radius: lifted ? 18 : 8, y: lifted ? 8 : 3)
    }

    private func artwork(in rect: CGRect) -> some View {
        ZStack {
            if let frost, !reduceTransparency {
                Image(nsImage: frost)
                    .resizable()
                    .scaledToFill()
            }
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .opacity(reduceTransparency ? 1 : 0.84)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: max(14, rect.width * 0.12), weight: .regular))
                    .foregroundColor(ShotliGlass.ink.opacity(0.28))
            }
        }
        .frame(width: rect.width, height: rect.height)
        .clipped()
        .clipShape(GlassDocumentPage(geometry: GlassDocumentGeometry(rect: rect, style: style)))
    }

    private var veil: LinearGradient {
        let amount = reduceTransparency ? min(0.72, style.veil + 0.4) : style.veil
        return LinearGradient(
            colors: [
                Color.white.opacity(amount + 0.06),
                tint.opacity(amount * 0.45),
                Color.white.opacity(amount * 0.7),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var sheen: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(lifted ? 0.34 : 0.18),
                Color.white.opacity(0.02),
                Color.clear,
            ],
            startPoint: .top,
            endPoint: .center
        )
    }

    private func flap(_ geometry: GlassDocumentGeometry) -> some View {
        let shape = GlassDocumentFlap(geometry: geometry)
        return shape
            .fill(
                LinearGradient(
                colors: [
                    Color.white.opacity(lifted ? 0.42 : 0.30),
                    tint.opacity(0.2),
                    Color.white.opacity(0.08),
                ],
                    startPoint: .topTrailing,
                    endPoint: .bottomLeading
                )
            )
            .overlay(
                shape.stroke(Color.white.opacity(0.75), lineWidth: 0.8)
            )
            .shadow(color: Color.black.opacity(0.16), radius: 2.4, x: -1, y: 2)
    }

    private func crease(_ geometry: GlassDocumentGeometry) -> some View {
        GlassDocumentCrease(geometry: geometry)
            .stroke(Color.black.opacity(0.2), style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
            .shadow(color: Color.black.opacity(0.12), radius: 1.5, x: -0.6, y: 1.2)
    }
}

struct GlassDocumentGeometry: Equatable {
    var rect: CGRect
    var fold: CGFloat
    var radius: CGFloat
    var top: CGPoint
    var peak: CGPoint
    var side: CGPoint
    var tip: CGPoint
    var showsFold: Bool

    init(rect: CGRect, style: GlassDocumentStyle) {
        self.rect = rect
        let shortest = max(1, min(rect.width, rect.height))
        let fold = style.showsFold ? min(shortest * style.foldFraction, rect.width * 0.42, rect.height * 0.42) : 0
        let radius = min(shortest * style.radiusFraction, max(fold, shortest * 0.08) * 0.62, rect.width * 0.22)
        self.fold = fold
        self.radius = radius
        self.showsFold = style.showsFold && fold > 4
        top = CGPoint(x: rect.maxX - fold, y: rect.minY)
        peak = CGPoint(x: rect.maxX - fold * 0.40, y: rect.minY + fold * 0.15)
        side = CGPoint(x: rect.maxX, y: rect.minY + fold)
        tip = CGPoint(x: rect.maxX - fold * 0.64, y: rect.minY + fold * 0.64)
    }
}

struct GlassDocumentPage: Shape {
    var geometry: GlassDocumentGeometry

    func path(in rect: CGRect) -> Path {
        let geometry = GlassDocumentGeometry(rect: rect, style: Self.style(from: geometry))
        return geometry.pagePath()
    }

    static func style(from geometry: GlassDocumentGeometry) -> GlassDocumentStyle {
        let shortest = max(1, min(geometry.rect.width, geometry.rect.height))
        return GlassDocumentStyle(
            foldFraction: geometry.showsFold ? geometry.fold / shortest : 0,
            radiusFraction: geometry.radius / shortest,
            showsFold: geometry.showsFold
        )
    }
}

struct GlassDocumentFlap: Shape {
    var geometry: GlassDocumentGeometry

    func path(in rect: CGRect) -> Path {
        let geometry = GlassDocumentGeometry(rect: rect, style: GlassDocumentPage.style(from: geometry))
        return geometry.flapPath()
    }
}

struct GlassDocumentCrease: Shape {
    var geometry: GlassDocumentGeometry

    func path(in rect: CGRect) -> Path {
        let geometry = GlassDocumentGeometry(rect: rect, style: GlassDocumentPage.style(from: geometry))
        return geometry.creasePath()
    }
}

extension GlassDocumentGeometry {
    func pagePath() -> Path {
        var path = Path()
        let radius = min(self.radius, rect.width * 0.2, rect.height * 0.2)
        if showsFold {
            path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
            path.addLine(to: top)
            path.addLine(to: peak)
            path.addLine(to: side)
        } else {
            path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
            path.addArc(
                tangent1End: CGPoint(x: rect.maxX, y: rect.minY),
                tangent2End: CGPoint(x: rect.maxX, y: rect.maxY),
                radius: radius
            )
        }
        path.addArc(
            tangent1End: CGPoint(x: rect.maxX, y: rect.maxY),
            tangent2End: CGPoint(x: rect.minX, y: rect.maxY),
            radius: radius
        )
        path.addArc(
            tangent1End: CGPoint(x: rect.minX, y: rect.maxY),
            tangent2End: CGPoint(x: rect.minX, y: rect.minY),
            radius: radius
        )
        path.addArc(
            tangent1End: CGPoint(x: rect.minX, y: rect.minY),
            tangent2End: CGPoint(x: rect.maxX, y: rect.minY),
            radius: radius
        )
        path.closeSubpath()
        return path
    }

    func flapPath() -> Path {
        var path = Path()
        guard showsFold else { return path }
        path.move(to: top)
        path.addLine(to: peak)
        path.addLine(to: side)
        path.addLine(to: tip)
        path.closeSubpath()
        return path
    }

    func creasePath() -> Path {
        var path = Path()
        guard showsFold else { return path }
        path.move(to: top)
        path.addLine(to: tip)
        path.addLine(to: side)
        return path
    }
}
