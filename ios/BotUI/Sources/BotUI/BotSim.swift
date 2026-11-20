import Foundation

/// The moods BotUI can be in. Switch at runtime; colour is independent.
public enum BotState: CaseIterable, Sendable {
    case neutral, happy, working, sleeping
    case thinking, idea, love, sad, surprised, angry, confused
    case excited, listening, speaking, success, error
    /// A short laugh. Touching BotUI triggers it.
    case giggle
}

/// One frame of motion, in the 100 x 100 body box (negative y is up). Angles in radians.
public struct BotPose: Equatable, Sendable {
    public var yaw: Double = 0, pitch: Double = 0, roll: Double = 0
    public var x: Double = 0, y: Double = 0, sx: Double = 1, sy: Double = 1
    public var blink: Double = 0
    public var lookX: Double = 0, lookY: Double = 0
    public var breath: Double = 0
    public var laugh: Double = 0
    public var sleep: Double = 0
    /// feather swing relative to the head, degrees
    public var swing: Double = 0
    /// 0 ... 1 mouth opening while speaking
    public var talk: Double = 0
    /// State being faded out, or nil once the change has finished.
    /// Seconds since the sim started; drives badges.
    public var time: Double = 0
    public var from: BotState?
    /// 0 ... 1 progress of the fade from `from` to the current state's face.
    public var blend: Double = 1
    public init() {}
}

/// Small seeded generator (mulberry32). Same sequence as the Android version.
struct SeededRandom {
    private var s: UInt32
    init(seed: Int32) { s = UInt32(bitPattern: seed) }

    mutating func next() -> Double {
        s = s &+ 0x6D2B79F5
        var t = s
        t = (t ^ (t >> 15)) &* (t | 1)
        t = t ^ (t &+ (t ^ (t >> 7)) &* (t | 61))
        return Double(t ^ (t >> 14)) / 4294967296.0
    }

    mutating func range(_ lo: Double, _ hi: Double) -> Double { lo + (hi - lo) * next() }
}

/// Tunables for the hop. Defaults follow the web and Android versions.
public struct BotJump: Sendable {
    public var height = 26.0, airTime = 0.68, anticipation = 0.14, landTime = 0.37
    public var squash = 1.15, spins = 1.0, leanDegrees = 6.0
    public init() {}
}

/// Drives blinks, glances, breathing and hops. Pure maths: call `update(dt:)` once a frame, read `pose`.
public final class BotSim {
    static let maxDt = 0.1
    private static let blinkTime = 0.16, moodRate = 6.0, trail = 6.0, faceFade = 0.22
    private static let maxSwing = 18.0, springK = 60.0, springD = 9.0

    private var rng: SeededRandom
    public private(set) var state: BotState
    public var jumpEvery: Double
    public private(set) var pose = BotPose()
    private let jump: BotJump
    private var t = 0.0

    private var pitchM = 0.0, rollM = 0.0, yM = 0.0, laughM = 0.0, sleepM = 0.0
    private var lookYM = 0.0, talkM = 0.0, wiggleM = 0.0, bounceM = 0.0
    private var fromState: BotState?
    private var blendT = 1.0
    private var motion: BotMotion { BotMotion.of(state) }
    private var blinkAt: Double, blinkT = -1.0, blinkAgain = false
    private var gazeAt: Double, gazeTarget = 0.0, gazeYaw = 0.0, gazeVel = 0.0, lookX = 0.0
    private var hopAt = 0.0, hopT = -1.0, hopDir = 1.0
    private var swing = 0.0, swingVel = 0.0, prevYaw = 0.0

    public static func defaultJumpEvery(_ s: BotState) -> Double {
        BotMotion.of(s).jumpEvery
    }

    public init(seed: Double, state: BotState = .neutral, jumpEvery: Double? = nil, jump: BotJump = BotJump()) {
        let clamped = min(max(seed, 0), 1)
        rng = SeededRandom(seed: Int32(clamped * 1_000_000) + 1)
        self.state = state
        self.jump = jump
        self.jumpEvery = jumpEvery ?? Self.defaultJumpEvery(state)
        blinkAt = rng.range(1.5, 3.5)
        gazeAt = rng.range(1.5, 3.5)
        hopAt = nextHop()
        pitchM = targetPitch(); rollM = targetRoll(); yM = targetY()
        laughM = targetLaugh(); sleepM = targetSleep(); lookYM = targetLookY(); talkM = targetTalk()
        wiggleM = motion.wiggle; bounceM = motion.bounce
    }

    public func setState(_ next: BotState, jumpEvery: Double? = nil) {
        guard next != state || jumpEvery != nil else { return }
        if next != state { fromState = state; blendT = 0 }
        state = next
        self.jumpEvery = jumpEvery ?? Self.defaultJumpEvery(next)
        if hopT < 0 { hopAt = t + nextHop() }
    }

    /// A hop and a full turn, right now.
    public func poke() { if hopT < 0 { startHop() } }

    public func update(dt raw: Double) {
        let dt = min(max(raw, 0), Self.maxDt)
        t += dt
        blendT = min(1, blendT + dt / Self.faceFade)
        if blendT >= 1 { fromState = nil }
        easeMood(dt); stepGaze(dt); stepBlink(dt); stepHop(dt); compose(dt)
    }

    private func nextHop() -> Double { jumpEvery <= 0 ? .greatestFiniteMagnitude : jumpEvery * rng.range(0.6, 1.4) }

    private func targetPitch() -> Double { motion.pitch }
    private func targetRoll() -> Double { motion.roll }
    private func targetY() -> Double { motion.y }
    private func targetLaugh() -> Double { BotFaceSpec.of(state).eyes == .arcUp ? 1 : 0 }
    private func targetSleep() -> Double { BotFaceSpec.of(state).eyes == .arcDown ? 1 : 0 }
    private func targetLookY() -> Double { state == .sleeping ? 1 : 0 }
    private func targetTalk() -> Double { state == .speaking || state == .giggle ? 1 : 0 }

    private func easeMood(_ dt: Double) {
        let k = 1 - exp(-Self.moodRate * dt)
        pitchM += (targetPitch() - pitchM) * k
        rollM += (targetRoll() - rollM) * k
        yM += (targetY() - yM) * k
        laughM += (targetLaugh() - laughM) * k
        sleepM += (targetSleep() - sleepM) * k
        lookYM += (targetLookY() - lookYM) * k
        talkM += (targetTalk() - talkM) * k
        wiggleM += (motion.wiggle - wiggleM) * k
        bounceM += (motion.bounce - bounceM) * k
    }

    private func stepGaze(_ dt: Double) {
        if t >= gazeAt {
            gazeTarget = (state == .sleeping || motion.holdHead) ? 0 : rng.range(-0.42, 0.42)
            gazeAt = t + rng.range(2.2, 4.5)
        }
        gazeVel += (40 * (gazeTarget - gazeYaw) - 11 * gazeVel) * dt
        gazeYaw += gazeVel * dt
        lookX += (gazeTarget - lookX) * (1 - exp(-14 * dt))
    }

    private func stepBlink(_ dt: Double) {
        if state == .sleeping { return }
        if blinkT < 0, t >= blinkAt {
            blinkT = 0
            blinkAgain = rng.next() < 0.2
        }
        if blinkT >= 0 {
            blinkT += dt
            if blinkT >= Self.blinkTime {
                blinkT = -1
                if blinkAgain { blinkAgain = false; blinkAt = t + 0.12 } else { blinkAt = t + rng.range(2, 5.5) }
            }
        }
    }

    private func startHop() {
        hopT = 0
        hopDir = rng.next() < 0.5 ? 1 : -1
    }

    private func hopDuration() -> Double { jump.anticipation + jump.airTime + jump.landTime }

    private func stepHop(_ dt: Double) {
        if hopT < 0 {
            if state != .sleeping, jumpEvery > 0, t >= hopAt { startHop() }
            return
        }
        hopT += dt
        if hopT >= hopDuration() { hopT = -1; hopAt = t + nextHop() }
    }

    private func compose(_ dt: Double) {
        var y = yM - bounceM * abs(sin(t * 14)), sx = 1.0, sy = 1.0, yaw = gazeYaw
        var roll = rollM + wiggleM * sin(t * 28)
        let pitch = pitchM + motion.nod * sin(t * 2 * .pi * 0.7)
        let burst = max(0, sin(t * 2.2)); let shakeX = motion.shake * burst * burst * sin(t * 38)
        if hopT >= 0 {
            let h = hopFrame(hopT)
            y += h.y; sx = h.sx; sy = h.sy; yaw = gazeYaw + h.yaw; roll += h.roll
        }
        let breath = sin(t * 2 * .pi / 3.6)
        let breathScale = 0.012 * (1 - sleepM * 0.3)
        sy *= 1 + breath * breathScale
        sx *= 1 - breath * breathScale * 0.6

        if motion.pulse > 0 {
            let beat = pow(max(0, sin(t * 2 * .pi / 1.3)), 6)
            sy *= 1 + motion.pulse * beat
            sx *= 1 + motion.pulse * 0.6 * beat
        }
        let talkWave = state == .giggle
            ? 0.5 + 0.5 * sin(t * 24)
            : (0.5 + 0.5 * sin(t * 13)) * (0.55 + 0.45 * sin(t * 4.7 + 1))
        let talk = talkM * talkWave

        let blink = blinkT >= 0 ? blinkCurve(blinkT / Self.blinkTime) : 0
        let yawVel = dt > 0 ? (yaw - prevYaw) / dt : 0
        prevYaw = yaw
        let target = min(max(-yawVel * Self.trail + roll * 180 / .pi * 0.3, -Self.maxSwing), Self.maxSwing)
        swingVel += (Self.springK * (target - swing) - Self.springD * swingVel) * dt
        swing += swingVel * dt

        var p = BotPose()
        p.yaw = yaw; p.pitch = pitch; p.roll = roll; p.x = shakeX; p.y = y; p.sx = sx; p.sy = sy
        p.blink = blink; p.lookX = lookX; p.lookY = lookYM
        p.breath = breath; p.laugh = laughM; p.sleep = sleepM; p.swing = swing
        p.talk = talk; p.time = t; p.from = fromState; p.blend = smooth(blendT)
        pose = p
    }

    private struct HopFrame { var y, sx, sy, yaw, roll: Double }

    private func hopFrame(_ time: Double) -> HopFrame {
        let pre = jump.anticipation, air = jump.airTime
        if time < pre {
            let k = smooth(time / pre)
            return HopFrame(y: 0, sx: 1 + 0.10 * k, sy: 1 - 0.16 * k, yaw: 0, roll: 0)
        }
        if time < pre + air {
            let u = (time - pre) / air
            let arc = sin(u * .pi)
            return HopFrame(
                y: -jump.height * 4 * u * (1 - u), sx: 1 - 0.07 * arc, sy: 1 + 0.12 * arc,
                yaw: hopDir * 2 * .pi * jump.spins * easeInOut(u),
                roll: hopDir * jump.leanDegrees * .pi / 180 * arc)
        }
        let p = min(max((time - pre - air) / jump.landTime, 0), 1)
        let d = 0.2 * jump.squash / 1.15 * sin(p * .pi) * (1 - 0.4 * p)
        return HopFrame(y: 0, sx: 1 + 0.7 * d, sy: 1 - d, yaw: 0, roll: 0)
    }

    private func smooth(_ v: Double) -> Double { v * v * (3 - 2 * v) }
    private func easeInOut(_ u: Double) -> Double {
        if u < 0.5 { return 4 * u * u * u }
        let w = -2 * u + 2
        return 1 - w * w * w / 2
    }
    private func blinkCurve(_ p: Double) -> Double { 1 - min(1, max(0, abs(2 * p - 1))) }
}
