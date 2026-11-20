#if canImport(UIKit)
import SwiftUI
import UIKit

private let centre = CGPoint(x: 50, y: 55)
private let pivot = CGPoint(x: 50, y: 98)

/// Owns the sim and the baked art. A plain class so the draw closure can step it.
private final class Driver: ObservableObject {
    let sim: BotSim
    private var last: Date?
    private var artKey: BodyArt.Key?
    private var art: UIImage?

    init(seed: Double, state: BotState, jumpEvery: Double?) {
        sim = BotSim(seed: seed, state: state, jumpEvery: jumpEvery)
    }

    func step(_ now: Date, paused: Bool) {
        defer { last = now }
        guard !paused, let last else { return }
        sim.update(dt: now.timeIntervalSince(last))
    }

    func body(_ style: BotStyle, seed: Double) -> UIImage {
        let s = Int32(min(max(seed, 0), 1) * 1_000_000) + 7
        let key = BodyArt.key(style, seed: s)
        if let art, key == artKey { return art }
        let made = BodyArt.bake(style, seed: s)
        artKey = key; art = made
        return made
    }
}

/// BotUI, the fuzzy teardrop companion, drawn natively in SwiftUI. Pick a colour and a mood at runtime.
public struct BotView: View {
    /// Room around the 100-unit body box so fur and badges are not clipped.
    private static let margin = 15.0
    private let state: BotState
    private let style: BotStyle
    private let seed: Double
    private let paused: Bool
    private let touchReactions: Bool
    private let onTouch: ((BotState) -> Void)?
    @State private var reaction: Reaction?
    @StateObject private var driver: Driver
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// - Parameters:
    ///   - touchReactions: tap to make BotUI giggle, press and hold for love.
    ///   - onTouch: called with the state a touch triggered.
    public init(state: BotState, style: BotStyle = BotStyle(), seed: Double = 0.11, paused: Bool = false,
                touchReactions: Bool = true, onTouch: ((BotState) -> Void)? = nil) {
        self.state = state; self.style = style; self.seed = seed; self.paused = paused
        self.touchReactions = touchReactions; self.onTouch = onTouch
        _driver = StateObject(wrappedValue: Driver(seed: seed, state: state, jumpEvery: style.jumpEverySeconds))
    }

    /// A touch reaction. It only counts while the parent state it started from is unchanged.
    private struct Reaction: Equatable {
        let id = UUID()
        let base: BotState
        let state: BotState
        let millis: UInt64
    }

    private static let giggleMillis: UInt64 = 1600, loveMillis: UInt64 = 2400

    private var shown: BotState {
        if let reaction, reaction.base == state { return reaction.state }
        return state
    }

    public var body: some View {
        let now = shown
        TimelineView(.animation(paused: paused || reduceMotion)) { tl in
            Canvas { ctx, size in
                driver.step(tl.date, paused: paused || reduceMotion)
                driver.sim.setState(now, jumpEvery: style.jumpEverySeconds)
                draw(&ctx, size: size, pose: driver.sim.pose, art: driver.body(style, seed: seed), state: now)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .contentShape(Rectangle())
        .modifier(TouchModifier(enabled: touchReactions, tap: { react(.giggle, Self.giggleMillis) },
                                hold: { react(.love, Self.loveMillis) }))
        .task(id: reaction?.id) {
            guard let r = reaction else { return }
            try? await Task.sleep(nanoseconds: r.millis * 1_000_000)
            if !Task.isCancelled, reaction?.id == r.id { reaction = nil }
        }
    }

    private func react(_ next: BotState, _ millis: UInt64) {
        // a tap while loving keeps loving, but a long press may take over
        if shown == .love, next == .giggle, reaction != nil { return }
        reaction = Reaction(base: state, state: next, millis: millis)
        onTouch?(next)
    }

    private func draw(_ ctx: inout GraphicsContext, size: CGSize, pose: BotPose, art: UIImage, state: BotState) {
        let s = min(size.width, size.height) / (100 + 2 * Self.margin)
        let cosY = cos(pose.yaw)
        let widthK = max(0.55, abs(cosY))
        let air = min(max(-pose.y / 30, 0), 1)

        var c = ctx
        c.translateBy(x: Self.margin * s, y: Self.margin * s)
        c.scaleBy(x: s, y: s)
        shadow(&c, air: air)
        let outline = style.shape.outline

        var body = c
        body.translateBy(x: pose.x, y: pose.y)
        scaleAbout(&body, pivot, pose.sx * widthK, pose.sy)
        body.translateBy(x: 50, y: 70)
        body.rotate(by: .radians(pose.roll))
        body.translateBy(x: -50, y: -70)
        body.draw(Image(uiImage: art), in: CGRect(x: -BodyArt.pad, y: -BodyArt.pad, width: BodyArt.span, height: BodyArt.span))
        let frontness = min(max((cosY - 0.1) / 0.4, 0), 1)
        if frontness < 1 { body.fill(Path(outline.cgPath()), with: .color(.black.opacity(0.14 * (1 - frontness)))) }
        if frontness > 0 { BotFaceDrawing.draw(&body, state: state, pose: pose, style: style, cosY: cosY, alpha: frontness) }

        var badge = c
        badge.translateBy(x: pose.x, y: pose.y)
        scaleAbout(&badge, pivot, pose.sx, pose.sy)
        BotBadges.draw(&badge, pose: pose, state: state)
    }

    private func scaleAbout(_ c: inout GraphicsContext, _ p: CGPoint, _ sx: Double, _ sy: Double) {
        c.translateBy(x: p.x, y: p.y); c.scaleBy(x: sx, y: sy); c.translateBy(x: -p.x, y: -p.y)
    }

    private func shadow(_ c: inout GraphicsContext, air: Double) {
        let w = 78 - air * 28
        let rect = CGRect(x: 50 - w / 2, y: 98 - 4.5, width: w, height: 9)
        let col = Color(red: 0.16, green: 0.27, blue: 0.43).opacity(0.32 * (1 - air * 0.55))
        c.fill(Path(ellipseIn: rect), with: .radialGradient(
            Gradient(colors: [col, .clear]), center: CGPoint(x: 50, y: 98), startRadius: 0, endRadius: w / 2))
    }
}

private struct TouchModifier: ViewModifier {
    let enabled: Bool
    let tap: () -> Void
    let hold: () -> Void

    func body(content: Content) -> some View {
        if enabled {
            content
                .onTapGesture(perform: tap)
                .onLongPressGesture(minimumDuration: 0.5, perform: hold)
        } else {
            content
        }
    }
}
#endif
