package dev.botui

import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.graphics.nativeCanvas
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin

/** A small picture that floats beside the head in some states. */
internal enum class BotBadge {
    None, Dots, Bulb;

    companion object {
        fun of(state: BotState): BotBadge = when (state) {
            BotState.Thinking -> Dots
            BotState.Idea -> Bulb
            else -> None
        }
    }
}

private val BUBBLE_EDGE = Color(0xFFC9CED6)
private val DOT_INK = Color(0xFF6B7280)
private const val BULB_SIZE = 15f
private val RAY = Color(0xFFFFB800)

/** Pop-in with a little overshoot; [k] runs 0 ... 1. */
private fun pop(k: Float): Float {
    val u = k.coerceIn(0f, 1f) - 1f
    return 1f + 2.7f * u * u * u + 1.7f * u * u
}

/** Draws the badge of the state we are leaving (shrinking) and the one we enter (popping). */
internal fun DrawScope.drawBadges(pose: BotPose, state: BotState) {
    val from = pose.from
    if (from != null && pose.blend < 1f) drawBadge(BotBadge.of(from), (1f - pose.blend), pose.time)
    drawBadge(BotBadge.of(state), if (from != null) pop(pose.blend) else 1f, pose.time)
}

private fun DrawScope.drawBadge(kind: BotBadge, scale: Float, time: Float) {
    if (kind == BotBadge.None || scale <= 0.01f) return
    val bob = sin(time * 2.2f) * 1.1f
    val centre = Offset(17f, 6f + bob)
    withScale(scale, centre) {
        when (kind) {
            BotBadge.Dots -> drawThought(centre, time)
            BotBadge.Bulb -> drawBulb(centre, time)
            BotBadge.None -> Unit
        }
    }
}

private fun DrawScope.withScale(s: Float, pivot: Offset, block: DrawScope.() -> Unit) {
    withTransform({ scale(s, s, pivot) }) { block() }
}

private fun DrawScope.drawThought(c: Offset, time: Float) {
    drawCircle(Color.White, 1.7f, Offset(c.x + 10f, c.y + 10f))
    drawCircle(BUBBLE_EDGE, 1.7f, Offset(c.x + 10f, c.y + 10f), style = Stroke(0.7f))
    drawCircle(Color.White, 1.1f, Offset(c.x + 14f, c.y + 12.6f))
    drawCircle(BUBBLE_EDGE, 1.1f, Offset(c.x + 14f, c.y + 12.6f), style = Stroke(0.6f))
    val tl = Offset(c.x - 14f, c.y - 7.5f)
    val sz = Size(28f, 15f)
    drawRoundRect(Color.White, tl, sz, CornerRadius(7.5f))
    drawRoundRect(BUBBLE_EDGE, tl, sz, CornerRadius(7.5f), style = Stroke(0.9f))
    for (i in 0 until 3) {
        val r = 1.9f * (0.72f + 0.28f * sin(time * 6f - i * 1.3f))
        drawCircle(DOT_INK, r, Offset(c.x - 7f + i * 7f, c.y))
    }
}

private val EMOJI_PAINT = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply {
    textSize = BULB_SIZE
    textAlign = android.graphics.Paint.Align.CENTER
}

/** The system light bulb emoji, with a few rays that pulse around it. */
private fun DrawScope.drawBulb(c: Offset, time: Float) {
    val glow = 0.45f + 0.4f * sin(time * 5f)
    for (deg in intArrayOf(-160, -125, -90, -55, -20)) {
        val a = deg * PI.toFloat() / 180f
        drawLine(RAY.copy(alpha = glow), Offset(c.x + cos(a) * 10.4f, c.y - 1f + sin(a) * 10.4f),
            Offset(c.x + cos(a) * 13.4f, c.y - 1f + sin(a) * 13.4f), strokeWidth = 1.3f, cap = StrokeCap.Round)
    }
    drawContext.canvas.nativeCanvas.drawText("\uD83D\uDCA1", c.x, c.y + BULB_SIZE * 0.33f, EMOJI_PAINT)
}
