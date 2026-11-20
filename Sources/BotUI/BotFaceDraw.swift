#if canImport(UIKit)
import SwiftUI

/// Draws the current face, plus the one fading out during a state change.
enum BotFaceDrawing {
    static func draw(_ c: inout GraphicsContext, state: BotState, pose: BotPose, style: BotStyle,
                     cosY: Double, alpha: Double) {
        let custom = style.customFace
        let fading = custom == nil && pose.from != nil && pose.blend < 1
        if fading, let from = pose.from {
            face(&c, BotFaceSpec.of(from), pose, style, cosY, alpha * (1 - pose.blend))
        }
        face(&c, custom ?? BotFaceSpec.of(state), pose, style, cosY, alpha * (fading ? pose.blend : 1))
    }

    private static func face(_ c: inout GraphicsContext, _ spec: BotFaceSpec, _ pose: BotPose,
                             _ style: BotStyle, _ cosY: Double, _ alpha: Double) {
        guard alpha > 0 else { return }
        let ink = style.ink.opacity(alpha)
        let cx = 50 + sin(pose.yaw) * 30 + (pose.lookX + spec.lookX) * 4
        let cy = 54 - pose.pitch * 22 + (pose.lookY + spec.lookY) * 3
        let f = max(cosY, 0.3)
        let gap = 12 * f
        let open = 1 - pose.blink * 0.92

        for side in [-1.0, 1.0] {
            let k = side > 0 ? (spec.eyeScaleRight ?? spec.eyeScale) : spec.eyeScale
            eye(&c, spec.eyes, ink, cx + side * gap, cy, f, k, open, tilt: side * spec.eyeTilt * Self.tiltDegrees)
        }
        if style.face == .eyesAndMouth, spec.mouth != .none {
            mouth(&c, spec, pose, ink, cx + spec.mouthShift * f, cy + 13, f)
        }
    }

    private static let tiltDegrees = 22.0

    /// Draws with the eye turned about its centre.
    private static func turned(_ c: inout GraphicsContext, _ degrees: Double, _ x: Double, _ y: Double,
                               _ draw: (inout GraphicsContext) -> Void) {
        var r = c
        r.translateBy(x: x, y: y); r.rotate(by: .degrees(degrees)); r.translateBy(x: -x, y: -y)
        draw(&r)
    }

    private static func oval(_ c: inout GraphicsContext, _ ink: Color, _ x: Double, _ y: Double, _ rx: Double, _ ry: Double) {
        guard ry > 0.05 else { return }
        c.fill(Path(ellipseIn: CGRect(x: x - rx, y: y - ry, width: rx * 2, height: ry * 2)), with: .color(ink))
    }

    private static func eye(_ c: inout GraphicsContext, _ shape: BotEyes, _ ink: Color,
                            _ ex: Double, _ cy: Double, _ f: Double, _ k: Double, _ open: Double, tilt: Double) {
        let w = 5.2 * (0.5 + 0.5 * f) * k
        let round = StrokeStyle(lineWidth: 2.6, lineCap: .round)
        switch shape {
        case .oval: turned(&c, tilt, ex, cy) { oval(&$0, ink, ex, cy, w, 7.4 * open * k) }
        case .slit: turned(&c, tilt, ex, cy) { oval(&$0, ink, ex, cy + 1, w * 1.1, 4.2 * open * k) }
        case .arcUp, .arcDown:
            let bend = (shape == .arcUp ? -5.5 : 4.5) * k
            var p = Path()
            p.move(to: CGPoint(x: ex - 5 * f, y: cy))
            p.addQuadCurve(to: CGPoint(x: ex + 5 * f, y: cy), control: CGPoint(x: ex, y: cy + bend))
            c.stroke(p, with: .color(ink), style: round)
        case .heart: c.fill(heart(ex, cy, 5.2 * (0.6 + 0.4 * f) * k), with: .color(ink))
        case .star: c.fill(star(ex, cy, 6.8 * (0.6 + 0.4 * f) * k), with: .color(ink))
        case .cross:
            let r = 3.8 * (0.6 + 0.4 * f) * k
            var p = Path()
            p.move(to: CGPoint(x: ex - r, y: cy - r)); p.addLine(to: CGPoint(x: ex + r, y: cy + r))
            p.move(to: CGPoint(x: ex + r, y: cy - r)); p.addLine(to: CGPoint(x: ex - r, y: cy + r))
            c.stroke(p, with: .color(ink), style: round)
        }
    }

    private static func heart(_ x: Double, _ y: Double, _ s: Double) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: x, y: y + s))
        p.addCurve(to: CGPoint(x: x, y: y - 0.35 * s), control1: CGPoint(x: x - 1.5 * s, y: y + 0.1 * s),
                   control2: CGPoint(x: x - 1.1 * s, y: y - 0.9 * s))
        p.addCurve(to: CGPoint(x: x, y: y + s), control1: CGPoint(x: x + 1.1 * s, y: y - 0.9 * s),
                   control2: CGPoint(x: x + 1.5 * s, y: y + 0.1 * s))
        p.closeSubpath()
        return p
    }

    private static func star(_ x: Double, _ y: Double, _ r: Double) -> Path {
        var p = Path()
        for i in 0..<10 {
            let rad = i % 2 == 0 ? r : r * 0.45
            let a = (-90 + Double(i) * 36) * .pi / 180
            let pt = CGPoint(x: x + cos(a) * rad, y: y + sin(a) * rad)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }

    private static func mouth(_ c: inout GraphicsContext, _ spec: BotFaceSpec, _ pose: BotPose,
                              _ ink: Color, _ cx: Double, _ my: Double, _ f: Double) {
        let m = spec.mouthScale * f, ms = spec.mouthScale
        let line = StrokeStyle(lineWidth: 2.4, lineCap: .round)
        var p = Path()
        switch spec.mouth {
        case .none: return
        case .dot: oval(&c, ink, cx, my + 2, 1.1, 1.1)
        case .grin:
            p.move(to: CGPoint(x: cx - 6 * m, y: my - 2))
            p.addQuadCurve(to: CGPoint(x: cx + 6 * m, y: my - 2), control: CGPoint(x: cx, y: my + 11 * ms))
            p.closeSubpath()
            c.fill(p, with: .color(ink))
        case .open: oval(&c, ink, cx, my + 2.5, 3.6 * m, 4.4 * ms)
        case .o: oval(&c, ink, cx, my + 3, 3.2 * m, 4.4 * ms)
        case .talk: oval(&c, ink, cx, my + 2, 4.2 * m, 0.9 + 4.6 * pose.talk)
        case .flat:
            p.move(to: CGPoint(x: cx - 5 * m, y: my + 1)); p.addLine(to: CGPoint(x: cx + 5 * m, y: my + 1))
            c.stroke(p, with: .color(ink), style: line)
        case .frown:
            p.move(to: CGPoint(x: cx - 5 * m, y: my + 4))
            p.addQuadCurve(to: CGPoint(x: cx + 5 * m, y: my + 4), control: CGPoint(x: cx, y: my - 2))
            c.stroke(p, with: .color(ink), style: line)
        case .wavy:
            p.move(to: CGPoint(x: cx - 6 * m, y: my + 2))
            p.addQuadCurve(to: CGPoint(x: cx, y: my + 2), control: CGPoint(x: cx - 3 * m, y: my - 1.5))
            p.addQuadCurve(to: CGPoint(x: cx + 6 * m, y: my + 2), control: CGPoint(x: cx + 3 * m, y: my + 5.5))
            c.stroke(p, with: .color(ink), style: line)
        case .smile:
            p.move(to: CGPoint(x: cx - 5 * m, y: my))
            p.addQuadCurve(to: CGPoint(x: cx + 5 * m, y: my), control: CGPoint(x: cx, y: my + 5 * ms))
            c.stroke(p, with: .color(ink), style: line)
        }
    }
}
#endif
