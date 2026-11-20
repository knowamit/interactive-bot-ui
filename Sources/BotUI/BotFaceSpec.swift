import Foundation

public enum BotEyes: CaseIterable, Sendable { case oval, arcUp, arcDown, heart, star, cross, slit }

public enum BotMouth: CaseIterable, Sendable { case none, smile, grin, open, o, flat, frown, wavy, dot, talk }

/// A whole face as plain numbers. Every named `BotState` is a preset of this,
/// and you can pass your own through `BotStyle.customFace` to build any state.
public struct BotFaceSpec: Equatable, Sendable {
    public var eyes: BotEyes
    public var mouth: BotMouth
    /// Eye size, 1 = normal.
    public var eyeScale: Double
    /// Right eye size; nil = same as `eyeScale`.
    public var eyeScaleRight: Double?
    /// Extra gaze shift in face units, on top of the random glances.
    public var lookX: Double, lookY: Double
    public var mouthScale: Double
    /// Sideways mouth shift in body units.
    public var mouthShift: Double
    /// Turns oval and slit eyes: + sad (outer ends down), - angry (inner ends down). -1 ... 1
    public var eyeTilt: Double

    public init(
        eyes: BotEyes = .oval, mouth: BotMouth = .smile, eyeScale: Double = 1,
        eyeScaleRight: Double? = nil, lookX: Double = 0, lookY: Double = 0, mouthScale: Double = 1,
        mouthShift: Double = 0, eyeTilt: Double = 0
    ) {
        self.eyes = eyes; self.mouth = mouth; self.eyeScale = eyeScale; self.eyeScaleRight = eyeScaleRight
        self.lookX = lookX; self.lookY = lookY; self.mouthScale = mouthScale; self.mouthShift = mouthShift
        self.eyeTilt = eyeTilt
    }

    public static func of(_ state: BotState) -> BotFaceSpec {
        switch state {
        case .neutral, .happy: return BotFaceSpec()
        case .working: return BotFaceSpec(eyes: .arcUp, mouth: .grin)
        case .sleeping: return BotFaceSpec(eyes: .arcDown, mouth: .dot)
        case .thinking:
            return BotFaceSpec(mouth: .flat, lookX: 1.2, lookY: -1.4, mouthScale: 0.7, mouthShift: 4)
        case .idea: return BotFaceSpec(mouth: .open, eyeScale: 1.2, lookY: -1.2, mouthScale: 0.8)
        case .love: return BotFaceSpec(eyes: .heart)
        case .sad: return BotFaceSpec(mouth: .frown, eyeScale: 0.9, lookY: 1.4, eyeTilt: 0.8)
        case .surprised: return BotFaceSpec(mouth: .o, eyeScale: 1.35)
        case .angry: return BotFaceSpec(eyes: .slit, mouth: .frown, eyeScale: 0.95, eyeTilt: -1)
        case .confused:
            return BotFaceSpec(mouth: .wavy, eyeScale: 0.85, eyeScaleRight: 1.25, lookX: 1)
        case .excited: return BotFaceSpec(eyes: .star, mouth: .grin)
        case .listening: return BotFaceSpec(eyeScale: 1.15, mouthScale: 0.7)
        case .speaking: return BotFaceSpec(mouth: .talk)
        case .success: return BotFaceSpec(eyes: .arcUp, mouth: .grin, mouthScale: 1.15)
        case .error: return BotFaceSpec(eyes: .cross, mouth: .wavy)
        case .giggle: return BotFaceSpec(eyes: .arcUp, mouth: .talk, mouthScale: 1.3)
        }
    }
}

/// How the body moves in a state. The face comes from `BotFaceSpec`.
struct BotMotion {
    var pitch = 0.0, roll = 0.0, y = 0.0
    var jumpEvery = 0.0
    var shake = 0.0, nod = 0.0, pulse = 0.0
    /// Quick side to side tilt, radians (a giggle).
    var wiggle = 0.0
    /// Small rapid bounces in place, body units.
    var bounce = 0.0
    var holdHead = false

    static func of(_ s: BotState) -> BotMotion {
        switch s {
        case .neutral: return BotMotion()
        case .happy: return BotMotion(jumpEvery: 2.5)
        case .working: return BotMotion(pitch: 0.087, jumpEvery: 2.5)
        case .sleeping: return BotMotion(pitch: -0.28, roll: 0.105, y: 3)
        case .thinking: return BotMotion(roll: -0.12, holdHead: true)
        case .idea: return BotMotion(pitch: 0.05, jumpEvery: 3)
        case .love: return BotMotion(pulse: 0.045)
        case .sad: return BotMotion(pitch: -0.14, y: 2, holdHead: true)
        case .surprised: return BotMotion(pitch: 0.06, jumpEvery: 4)
        case .angry: return BotMotion(pitch: -0.04, shake: 0.7, holdHead: true)
        case .confused: return BotMotion(roll: 0.14)
        case .excited: return BotMotion(jumpEvery: 1.4)
        case .listening: return BotMotion(roll: 0.1, nod: 0.04, holdHead: true)
        case .speaking: return BotMotion(nod: 0.03)
        case .success: return BotMotion(jumpEvery: 1.8)
        case .error: return BotMotion(pitch: -0.05, shake: 1.2, holdHead: true)
        case .giggle: return BotMotion(pitch: 0.04, wiggle: 0.07, bounce: 2.2)
        }
    }
}
