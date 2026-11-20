#if canImport(UIKit)
import SwiftUI

/// A small picture that floats beside the head in some states.
enum BotBadge {
    case none, dots, bulb

    static func of(_ state: BotState) -> BotBadge {
        switch state {
        case .thinking: return .dots
        case .idea: return .bulb
        default: return .none
        }
    }
}

private extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

private let bubbleEdge = Color(hex: 0xC9CED6), dotInk = Color(hex: 0x6B7280)
private let bulbSize = 15.0
private let rayColor = Color(hex: 0xFFB800)

enum BotBadges {
    /// Pop-in with a little overshoot; `k` runs 0 ... 1.
    private static func pop(_ k: Double) -> Double {
        let u = min(max(k, 0), 1) - 1
        return 1 + 2.7 * u * u * u + 1.7 * u * u
    }

    /// Draws the badge of the state we are leaving (shrinking) and the one we enter (popping).
    static func draw(_ c: inout GraphicsContext, pose: BotPose, state: BotState) {
        if let from = pose.from, pose.blend < 1 { one(&c, BotBadge.of(from), 1 - pose.blend, pose.time) }
        one(&c, BotBadge.of(state), pose.from != nil ? pop(pose.blend) : 1, pose.time)
    }

    private static func one(_ c: inout GraphicsContext, _ kind: BotBadge, _ scale: Double, _ time: Double) {
        guard kind != .none, scale > 0.01 else { return }
        let centre = CGPoint(x: 17, y: 6 + sin(time * 2.2) * 1.1)
        var g = c
        g.translateBy(x: centre.x, y: centre.y); g.scaleBy(x: scale, y: scale); g.translateBy(x: -centre.x, y: -centre.y)
        switch kind {
        case .dots: thought(&g, centre, time)
        case .bulb: bulb(&g, centre, time)
        case .none: break
        }
    }

    private static func disc(_ c: inout GraphicsContext, _ at: CGPoint, _ r: Double, fill: Color, edge: Color? = nil, edgeWidth: Double = 0.7) {
        let p = Path(ellipseIn: CGRect(x: at.x - r, y: at.y - r, width: r * 2, height: r * 2))
        c.fill(p, with: .color(fill))
        if let edge { c.stroke(p, with: .color(edge), lineWidth: edgeWidth) }
    }

    private static func thought(_ c: inout GraphicsContext, _ m: CGPoint, _ time: Double) {
        disc(&c, CGPoint(x: m.x + 10, y: m.y + 10), 1.7, fill: .white, edge: bubbleEdge)
        disc(&c, CGPoint(x: m.x + 14, y: m.y + 12.6), 1.1, fill: .white, edge: bubbleEdge, edgeWidth: 0.6)
        let box = Path(roundedRect: CGRect(x: m.x - 14, y: m.y - 7.5, width: 28, height: 15), cornerRadius: 7.5)
        c.fill(box, with: .color(.white))
        c.stroke(box, with: .color(bubbleEdge), lineWidth: 0.9)
        for i in 0..<3 {
            let r = 1.9 * (0.72 + 0.28 * sin(time * 6 - Double(i) * 1.3))
            disc(&c, CGPoint(x: m.x - 7 + Double(i) * 7, y: m.y), r, fill: dotInk)
        }
    }

    /// The system light bulb emoji, with a few rays that pulse around it.
    private static func bulb(_ c: inout GraphicsContext, _ m: CGPoint, _ time: Double) {
        let glow = 0.45 + 0.4 * sin(time * 5)
        for deg in [-160.0, -125, -90, -55, -20] {
            let a = deg * .pi / 180
            var p = Path()
            p.move(to: CGPoint(x: m.x + cos(a) * 10.4, y: m.y - 1 + sin(a) * 10.4))
            p.addLine(to: CGPoint(x: m.x + cos(a) * 13.4, y: m.y - 1 + sin(a) * 13.4))
            c.stroke(p, with: .color(rayColor.opacity(glow)), style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
        }
        c.draw(Text("\u{1F4A1}").font(.system(size: bulbSize)), at: CGPoint(x: m.x, y: m.y - 0.5), anchor: .center)
    }
}
#endif
