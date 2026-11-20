package dev.botui

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.sin

private val BOTH_SIDES = floatArrayOf(-1f, 1f)
private const val TILT_DEGREES = 22f

/** Draws the current face, plus the one fading out during a state change. */
internal fun DrawScope.drawFaces(
    pose: BotPose,
    state: BotState,
    style: BotStyle,
    cosY: Float,
    alpha: Float,
) {
    val to = style.customFace ?: BotFaceSpec.of(state)
    val from = pose.from
    if (from != null && style.customFace == null && pose.blend < 1f) {
        drawFace(BotFaceSpec.of(from), pose, style, cosY, alpha * (1f - pose.blend))
    }
    val fade = if (from != null && style.customFace == null) pose.blend else 1f
    drawFace(to, pose, style, cosY, alpha * fade)
}

private fun DrawScope.drawFace(spec: BotFaceSpec, pose: BotPose, style: BotStyle, cosY: Float, alpha: Float) {
    if (alpha <= 0f) return
    val ink = style.ink.copy(alpha = style.ink.alpha * alpha)
    val cx = 50f + kotlin.math.sin(pose.yaw) * 30f + (pose.lookX + spec.lookX) * 4f
    val cy = 54f - pose.pitch * 22f + (pose.lookY + spec.lookY) * 3f
    val f = max(cosY, 0.3f)
    val gap = 12f * f
    val open = 1f - pose.blink * 0.92f

    for (side in BOTH_SIDES) {
        val scale = if (side > 0f) spec.eyeScaleRight ?: spec.eyeScale else spec.eyeScale
        drawEye(spec.eyes, ink, cx + side * gap, cy, f, scale, open, side * spec.eyeTilt * TILT_DEGREES)
    }
    if (style.face == BotFace.EyesAndMouth && spec.mouth != BotMouth.None) {
        drawMouth(spec, pose, ink, cx + spec.mouthShift * f, cy + 13f, f)
    }
}

private fun DrawScope.drawEye(
    shape: BotEyes, ink: Color, ex: Float, cy: Float, f: Float, k: Float, open: Float, tilt: Float,
) {
    val w = 5.2f * (0.5f + 0.5f * f) * k
    when (shape) {
        BotEyes.Oval -> rotate(tilt, Offset(ex, cy)) { oval(ink, ex, cy, w, 7.4f * open * k) }
        BotEyes.Slit -> rotate(tilt, Offset(ex, cy + 1f)) { oval(ink, ex, cy + 1f, w * 1.1f, 4.2f * open * k) }
        BotEyes.ArcUp -> arc(ink, ex, cy, f, -5.5f * k)
        BotEyes.ArcDown -> arc(ink, ex, cy, f, 4.5f * k)
        BotEyes.Heart -> drawPath(heart(ex, cy, 5.2f * (0.6f + 0.4f * f) * k), ink)
        BotEyes.Star -> drawPath(star(ex, cy, 6.8f * (0.6f + 0.4f * f) * k), ink)
        BotEyes.Cross -> {
            val r = 3.8f * (0.6f + 0.4f * f) * k
            val p = Path().apply {
                moveTo(ex - r, cy - r); lineTo(ex + r, cy + r)
                moveTo(ex + r, cy - r); lineTo(ex - r, cy + r)
            }
            drawPath(p, ink, style = Stroke(2.6f, cap = StrokeCap.Round))
        }
    }
}

private fun DrawScope.oval(ink: Color, ex: Float, cy: Float, rx: Float, ry: Float) {
    if (ry <= 0.05f) return
    drawOval(ink, Offset(ex - rx, cy - ry), Size(rx * 2f, ry * 2f))
}

private fun DrawScope.arc(ink: Color, ex: Float, cy: Float, f: Float, bend: Float) {
    val p = Path().apply {
        moveTo(ex - 5f * f, cy)
        quadraticBezierTo(ex, cy + bend, ex + 5f * f, cy)
    }
    drawPath(p, ink, style = Stroke(2.6f, cap = StrokeCap.Round))
}

private fun heart(x: Float, y: Float, s: Float): Path = Path().apply {
    moveTo(x, y + s)
    cubicTo(x - 1.5f * s, y + 0.1f * s, x - 1.1f * s, y - 0.9f * s, x, y - 0.35f * s)
    cubicTo(x + 1.1f * s, y - 0.9f * s, x + 1.5f * s, y + 0.1f * s, x, y + s)
    close()
}

private fun star(x: Float, y: Float, r: Float): Path = Path().apply {
    for (i in 0 until 10) {
        val rad = if (i % 2 == 0) r else r * 0.45f
        val a = (-90f + i * 36f) * PI.toFloat() / 180f
        val px = x + cos(a) * rad
        val py = y + sin(a) * rad
        if (i == 0) moveTo(px, py) else lineTo(px, py)
    }
    close()
}

private fun DrawScope.drawMouth(spec: BotFaceSpec, pose: BotPose, ink: Color, cx: Float, my: Float, f: Float) {
    val m = spec.mouthScale * f
    val line = Stroke(2.4f, cap = StrokeCap.Round)
    when (spec.mouth) {
        BotMouth.None -> Unit
        BotMouth.Dot -> drawCircle(ink, 1.1f, Offset(cx, my + 2f))
        BotMouth.Grin -> drawPath(Path().apply {
            moveTo(cx - 6f * m, my - 2f)
            quadraticBezierTo(cx, my + 11f * spec.mouthScale, cx + 6f * m, my - 2f)
            close()
        }, ink)
        BotMouth.Open -> oval(ink, cx, my + 2.5f, 3.6f * m, 4.4f * spec.mouthScale)
        BotMouth.O -> oval(ink, cx, my + 3f, 3.2f * m, 4.4f * spec.mouthScale)
        BotMouth.Talk -> oval(ink, cx, my + 2f, 4.2f * m, 0.9f + 4.6f * pose.talk)
        BotMouth.Flat -> drawLine(ink, Offset(cx - 5f * m, my + 1f), Offset(cx + 5f * m, my + 1f),
            strokeWidth = 2.4f, cap = StrokeCap.Round)
        BotMouth.Frown -> drawPath(Path().apply {
            moveTo(cx - 5f * m, my + 4f)
            quadraticBezierTo(cx, my - 2f, cx + 5f * m, my + 4f)
        }, ink, style = line)
        BotMouth.Wavy -> drawPath(Path().apply {
            moveTo(cx - 6f * m, my + 2f)
            quadraticBezierTo(cx - 3f * m, my - 1.5f, cx, my + 2f)
            quadraticBezierTo(cx + 3f * m, my + 5.5f, cx + 6f * m, my + 2f)
        }, ink, style = line)
        BotMouth.Smile -> drawPath(Path().apply {
            moveTo(cx - 5f * m, my)
            quadraticBezierTo(cx, my + 5f * spec.mouthScale, cx + 5f * m, my)
        }, ink, style = line)
    }
}
