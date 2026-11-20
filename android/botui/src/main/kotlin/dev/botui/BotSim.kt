package dev.botui

import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.exp
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin

/** The moods BotUI can be in. Switch at runtime; colour is independent. */
enum class BotState {
    Neutral, Happy, Working, Sleeping,
    Thinking, Idea, Love, Sad, Surprised, Angry, Confused,
    Excited, Listening, Speaking, Success, Error, Giggle,
}

/** One frame of motion, in the 100 x 100 body box (negative y is up). Angles in radians. */
data class BotPose(
    val yaw: Float = 0f,
    val pitch: Float = 0f,
    val roll: Float = 0f,
    val x: Float = 0f,
    val y: Float = 0f,
    val sx: Float = 1f,
    val sy: Float = 1f,
    /** 0 open ... 1 shut */
    val blink: Float = 0f,
    val lookX: Float = 0f,
    val lookY: Float = 0f,
    /** -1 ... 1 breathing cycle */
    val breath: Float = 0f,
    /** 0 ... 1: eyes closed into a laugh (^ ^) */
    val laugh: Float = 0f,
    /** 0 ... 1: eyes shut for sleep */
    val sleep: Float = 0f,
    /** feather swing relative to the head, degrees */
    val swing: Float = 0f,
    /** 0 ... 1 mouth opening while [BotState.Speaking] */
    val talk: Float = 0f,
    /** State being faded out, or null once the change has finished. */
    val from: BotState? = null,
    /** 0 ... 1 progress of the fade from [from] to the current state's face. */
    val blend: Float = 1f,
    /** Seconds since the sim started; drives badges. */
    val time: Float = 0f,
)

/** Small seeded generator (mulberry32) so a given seed always plays the same. */
internal class SeededRandom(seed: Int) {
    private var s = seed

    fun next(): Float {
        s += 0x6D2B79F5
        var t = s
        t = (t xor (t ushr 15)) * (t or 1)
        t = t xor (t + (t xor (t ushr 7)) * (t or 61))
        return ((t xor (t ushr 14)).toLong() and 0xFFFFFFFFL).toFloat() / 4294967296f
    }

    fun range(lo: Float, hi: Float): Float = lo + (hi - lo) * next()
}

/** Tunables for the hop. Defaults follow the web version. */
data class BotJump(
    val height: Float = 26f,
    val airTime: Float = 0.68f,
    val anticipation: Float = 0.14f,
    val landTime: Float = 0.37f,
    val squash: Float = 1.15f,
    val spins: Int = 1,
    val leanDegrees: Float = 6f,
)

/**
 * Drives blinks, glances, breathing and hops. Pure maths, no Android types:
 * call [update] once a frame, read [pose].
 */
class BotSim(
    seed: Float,
    state: BotState = BotState.Neutral,
    jumpEvery: Float = defaultJumpEvery(state),
    private val jump: BotJump = BotJump(),
) {
    private val rng = SeededRandom((seed.coerceIn(0f, 1f) * 1_000_000f).toInt() + 1)

    var state: BotState = state
        private set

    /** Seconds between hops, give or take 40%; 0 for none. */
    var jumpEvery: Float = jumpEvery

    var pose: BotPose = BotPose()
        private set

    private var t = 0f

    // blended mood values, eased toward the state's targets
    private var pitchM = 0f
    private var rollM = 0f
    private var yM = 0f
    private var laughM = 0f
    private var sleepM = 0f
    private var lookYM = 0f
    private var talkM = 0f
    private var wiggleM = 0f
    private var bounceM = 0f

    // face crossfade
    private var fromState: BotState? = null
    private var blendT = 1f

    // blink
    private var blinkAt = rng.range(1.5f, 3.5f)
    private var blinkT = -1f
    private var blinkAgain = false

    // gaze (head turn + eyes leading it)
    private var gazeAt = rng.range(1.5f, 3.5f)
    private var gazeTarget = 0f
    private var gazeYaw = 0f
    private var gazeVel = 0f
    private var lookX = 0f

    // hop
    private var hopAt = nextHop()
    private var hopT = -1f
    private var hopDir = 1f

    // feather spring
    private var swing = 0f
    private var swingVel = 0f
    private var prevYaw = 0f

    init {
        snapMood()
    }

    fun setState(next: BotState, jumpEvery: Float = defaultJumpEvery(next)) {
        if (next != state) {
            fromState = state
            blendT = 0f
        }
        state = next
        this.jumpEvery = jumpEvery
        hopAt = if (hopT < 0f) t + nextHop() else hopAt
    }

    /** A hop and a full turn, right now. */
    fun poke() {
        if (hopT < 0f) startHop()
    }

    fun update(dtRaw: Float) {
        val dt = dtRaw.coerceIn(0f, MAX_DT)
        t += dt
        easeMood(dt)
        blendT = min(1f, blendT + dt / FACE_FADE)
        if (blendT >= 1f) fromState = null
        stepGaze(dt)
        stepBlink(dt)
        stepHop(dt)
        compose(dt)
    }

    private fun nextHop(): Float =
        if (jumpEvery <= 0f) Float.MAX_VALUE else jumpEvery * rng.range(0.6f, 1.4f)

    private val motion get() = BotMotion.of(state)

    private fun targetPitch() = motion.pitch
    private fun targetRoll() = motion.roll
    private fun targetY() = motion.y
    private fun targetLaugh() = if (BotFaceSpec.of(state).eyes == BotEyes.ArcUp) 1f else 0f
    private fun targetSleep() = if (BotFaceSpec.of(state).eyes == BotEyes.ArcDown) 1f else 0f
    private fun targetLookY() = if (state == BotState.Sleeping) 1f else 0f
    private fun targetTalk() = if (state == BotState.Speaking || state == BotState.Giggle) 1f else 0f
    private fun targetWiggle() = motion.wiggle
    private fun targetBounce() = motion.bounce

    private fun snapMood() {
        pitchM = targetPitch(); rollM = targetRoll(); yM = targetY()
        laughM = targetLaugh(); sleepM = targetSleep(); lookYM = targetLookY()
        talkM = targetTalk(); wiggleM = targetWiggle(); bounceM = targetBounce()
    }

    private fun easeMood(dt: Float) {
        val k = 1f - exp(-MOOD_RATE * dt)
        pitchM += (targetPitch() - pitchM) * k
        rollM += (targetRoll() - rollM) * k
        yM += (targetY() - yM) * k
        laughM += (targetLaugh() - laughM) * k
        sleepM += (targetSleep() - sleepM) * k
        lookYM += (targetLookY() - lookYM) * k
        talkM += (targetTalk() - talkM) * k
        wiggleM += (targetWiggle() - wiggleM) * k
        bounceM += (targetBounce() - bounceM) * k
    }

    private fun stepGaze(dt: Float) {
        val still = state == BotState.Sleeping || motion.holdHead
        if (t >= gazeAt) {
            gazeTarget = if (still) 0f else rng.range(-0.42f, 0.42f)
            gazeAt = t + rng.range(2.2f, 4.5f)
        }
        // critically damped follow
        val accel = 40f * (gazeTarget - gazeYaw) - 11f * gazeVel
        gazeVel += accel * dt
        gazeYaw += gazeVel * dt
        // eyes run ahead of the head, then settle
        lookX += (gazeTarget - lookX) * (1f - exp(-14f * dt))
    }

    private fun stepBlink(dt: Float) {
        if (state == BotState.Sleeping) return
        if (blinkT < 0f && t >= blinkAt) {
            blinkT = 0f
            blinkAgain = rng.next() < 0.2f
        }
        if (blinkT >= 0f) {
            blinkT += dt
            if (blinkT >= BLINK_TIME) {
                blinkT = -1f
                if (blinkAgain) {
                    blinkAgain = false
                    blinkAt = t + 0.12f
                } else {
                    blinkAt = t + rng.range(2f, 5.5f)
                }
            }
        }
    }

    private fun startHop() {
        hopT = 0f
        hopDir = if (rng.next() < 0.5f) 1f else -1f
    }

    private fun stepHop(dt: Float) {
        if (hopT < 0f) {
            if (state != BotState.Sleeping && jumpEvery > 0f && t >= hopAt) startHop()
            return
        }
        hopT += dt
        if (hopT >= hopDuration()) {
            hopT = -1f
            hopAt = t + nextHop()
        }
    }

    private fun hopDuration() = jump.anticipation + jump.airTime + jump.landTime

    private fun compose(dt: Float) {
        var x = 0f
        var y = yM - bounceM * abs(sin(t * 14f))
        var sx = 1f
        var sy = 1f
        var yaw = gazeYaw
        var roll = rollM + wiggleM * sin(t * 28f)
        var pitch = pitchM + motion.nod * sin(t * 2f * PI.toFloat() * 0.7f)
        val burst = max(0f, sin(t * 2.2f)).let { it * it }
        x = motion.shake * burst * sin(t * 38f)
        if (hopT >= 0f) {
            val h = hopFrame(hopT)
            y += h.y; sx = h.sx; sy = h.sy
            yaw = gazeYaw + h.yaw
            roll += h.roll
        }

        val breath = sin(t * 2f * PI.toFloat() / 3.6f)
        val breathScale = 0.012f * (1f - sleepM * 0.3f)
        sy *= 1f + breath * breathScale
        sx *= 1f - breath * breathScale * 0.6f
        if (motion.pulse > 0f) {
            val beat = Math.pow(max(0f, sin(t * 2f * PI.toFloat() / 1.3f)).toDouble(), 6.0).toFloat()
            sy *= 1f + motion.pulse * beat
            sx *= 1f + motion.pulse * 0.6f * beat
        }
        val talkWave = if (state == BotState.Giggle) 0.5f + 0.5f * sin(t * 24f)
        else (0.5f + 0.5f * sin(t * 13f)) * (0.55f + 0.45f * sin(t * 4.7f + 1f))
        val talk = talkM * talkWave

        val blink = if (blinkT >= 0f) blinkCurve(blinkT / BLINK_TIME) else 0f

        // feather lags behind a head turn, like the web version
        val yawVel = if (dt > 0f) (yaw - prevYaw) / dt else 0f
        prevYaw = yaw
        val swingTarget = (-yawVel * TRAIL + roll * 180f / PI.toFloat() * 0.3f)
            .coerceIn(-MAX_SWING, MAX_SWING)
        swingVel += (SPRING_K * (swingTarget - swing) - SPRING_D * swingVel) * dt
        swing += swingVel * dt

        pose = BotPose(
            yaw = yaw, pitch = pitch, roll = roll, x = x, y = y, sx = sx, sy = sy,
            blink = blink, lookX = lookX, lookY = lookYM,
            breath = breath, laugh = laughM, sleep = sleepM, swing = swing,
            talk = talk, from = fromState, blend = smooth(blendT), time = t,
        )
    }

    private data class HopFrame(val y: Float, val sx: Float, val sy: Float, val yaw: Float, val roll: Float)

    private fun hopFrame(time: Float): HopFrame {
        val pre = jump.anticipation
        val air = jump.airTime
        return when {
            time < pre -> {
                val k = smooth(time / pre)
                HopFrame(0f, 1f + 0.10f * k, 1f - 0.16f * k, 0f, 0f)
            }
            time < pre + air -> {
                val u = (time - pre) / air
                val arc = sin(u * PI.toFloat())
                val turn = hopDir * 2f * PI.toFloat() * jump.spins * easeInOut(u)
                val lean = hopDir * jump.leanDegrees * PI.toFloat() / 180f * arc
                HopFrame(
                    y = -jump.height * 4f * u * (1f - u),
                    sx = 1f - 0.07f * arc,
                    sy = 1f + 0.12f * arc,
                    yaw = turn,
                    roll = lean,
                )
            }
            else -> {
                val p = ((time - pre - air) / jump.landTime).coerceIn(0f, 1f)
                val d = 0.2f * jump.squash / 1.15f * sin(p * PI.toFloat()) * (1f - 0.4f * p)
                HopFrame(0f, 1f + 0.7f * d, 1f - d, 0f, 0f)
            }
        }
    }

    private fun smooth(v: Float) = v * v * (3f - 2f * v)
    private fun easeInOut(u: Float) = if (u < 0.5f) 4f * u * u * u else 1f - (-2f * u + 2f).let { it * it * it } / 2f
    private fun blinkCurve(p: Float) = 1f - abs(2f * p - 1f).let { min(1f, max(0f, it)) }

    companion object {
        const val MAX_DT = 0.1f
        private const val BLINK_TIME = 0.16f
        private const val MOOD_RATE = 6f
        private const val FACE_FADE = 0.22f
        private const val TRAIL = 6f
        private const val MAX_SWING = 18f
        private const val SPRING_K = 60f
        private const val SPRING_D = 9f

        fun defaultJumpEvery(state: BotState): Float = BotMotion.of(state).jumpEvery
    }
}
