package dev.botui

import android.provider.Settings
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.ui.input.pointer.pointerInput
import kotlinx.coroutines.delay
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Canvas as GfxCanvas
import androidx.compose.ui.graphics.FilterQuality
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.drawscope.CanvasDrawScope
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PointMode
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.sin

private const val PIVOT_X = 50f
private const val PIVOT_Y = 98f
private val CENTRE = Offset(50f, 55f)

/**
 * BotUI, the fuzzy teardrop companion. Drawn natively on a Compose [Canvas]:
 * no web view, no bitmaps for the body, so [style] changes apply instantly.
 *
 * Give it room above the head if you set a feather: it sticks out past the box.
 */
@Composable
fun BotView(
    state: BotState,
    modifier: Modifier = Modifier,
    style: BotStyle = BotStyle(),
    seed: Float = 0.11f,
    paused: Boolean = false,
    /** Tap to make BotUI giggle, press and hold for love. */
    touchReactions: Boolean = true,
    /** Called with the state a touch triggered. */
    onTouch: ((BotState) -> Unit)? = null,
) {
    var reaction by remember(state) { mutableStateOf<Reaction?>(null) }
    LaunchedEffect(reaction) {
        val r = reaction ?: return@LaunchedEffect
        delay(r.millis)
        reaction = null
    }
    val shown = reaction?.state ?: state
    val sim = remember(seed) { BotSim(seed, shown, style.jumpEverySeconds ?: BotSim.defaultJumpEvery(shown)) }
    var pose by remember(sim) { mutableStateOf(sim.pose) }
    val still = paused || animationsOff()

    LaunchedEffect(sim, shown, style.jumpEverySeconds) {
        sim.setState(shown, style.jumpEverySeconds ?: BotSim.defaultJumpEvery(shown))
    }
    LaunchedEffect(sim, still) {
        if (still) return@LaunchedEffect
        var last = 0L
        while (true) {
            androidx.compose.runtime.withFrameNanos { now ->
                val dt = if (last == 0L) 0f else (now - last) / 1_000_000_000f
                last = now
                sim.update(dt)
                pose = sim.pose
            }
        }
    }

    val path = remember(style.shape) { style.shape.toPath() }
    val anchor = remember(path) { featherAnchor(path) }
    val fur = remember(seed, path, style.furLength, style.furDensity) {
        Fur.build(path, (seed * 1_000_000f).toInt() + 7, style.furLength, style.furDensity)
    }

    val bodyArt = remember(path, fur, style.color, style.brightness) {
        bakeBody(path, fur, shadeColor(style.color, style.brightness))
    }

    val touch = if (!touchReactions) Modifier else Modifier.pointerInput(state) {
        detectTapGestures(
            onTap = { fire(reaction, BotState.Giggle, GIGGLE_MS) { reaction = it; onTouch?.invoke(BotState.Giggle) } },
            onLongPress = { fire(reaction, BotState.Love, LOVE_MS) { reaction = it; onTouch?.invoke(BotState.Love) } },
        )
    }
    Canvas(modifier.aspectRatio(1f).then(touch)) {
        drawBot(pose, shown, style, path, bodyArt, anchor)
    }
}

private const val GIGGLE_MS = 1600L
private const val LOVE_MS = 2400L

/** A touch reaction; each gets a fresh id so a repeat tap restarts the timer. */
private class Reaction(val state: BotState, val millis: Long)

private fun fire(current: Reaction?, state: BotState, millis: Long, set: (Reaction) -> Unit) {
    // a tap while giggling keeps giggling, but a long press may take over
    if (current?.state == BotState.Love && state == BotState.Giggle) return
    set(Reaction(state, millis))
}

/** Where the feather pins: right of the crown, same proportions as the teardrop. */
private fun featherAnchor(path: Path): Offset {
    val b = path.getBounds()
    return Offset(b.left + b.width * 0.6375f, b.top + b.height * 0.169f)
}

@Composable
private fun animationsOff(): Boolean {
    val resolver = LocalContext.current.contentResolver
    return remember {
        runCatching {
            Settings.Global.getFloat(resolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) == 0f
        }.getOrDefault(false)
    }
}

private fun shadeColor(c: Color, k: Float): Color =
    Color((c.red * k).coerceIn(0f, 1f), (c.green * k).coerceIn(0f, 1f), (c.blue * k).coerceIn(0f, 1f), c.alpha)

private fun DrawScope.drawBot(
    pose: BotPose,
    state: BotState,
    style: BotStyle,
    path: Path,
    bodyArt: ImageBitmap,
    anchor: Offset,
) {
    val s = size.minDimension / 100f
    val base = shadeColor(style.color, style.brightness)
    val cosY = cos(pose.yaw)
    val widthK = max(0.55f, abs(cosY))
    val rollDeg = pose.roll * 180f / PI.toFloat()
    val pivot = Offset(PIVOT_X, PIVOT_Y)

    val air = (-pose.y / 30f).coerceIn(0f, 1f)
    drawGroundShadow(s, air)

    // body: squash, stretch, turn and tilt about the feet
    withTransform({
        scale(s, s, Offset.Zero)
        translate(pose.x, pose.y)
        scale(pose.sx * widthK, pose.sy, pivot)
        rotate(rollDeg, Offset(50f, 70f))
    }) {
        drawBody(path, bodyArt, cosY, pose, state, style, base)
    }

    // ornament: follows the head's turn and the hop, not the width squeeze
    style.feather?.let { bmp ->
        withTransform({
            scale(s, s, Offset.Zero)
            translate(pose.x, pose.y)
            scale(pose.sx, pose.sy, pivot)
        }) {
            drawFeather(bmp, pose, anchor)
        }
    }

    // badge: floats beside the head, follows the hop
    withTransform({
        scale(s, s, Offset.Zero)
        translate(pose.x, pose.y)
        scale(pose.sx, pose.sy, pivot)
    }) {
        drawBadges(pose, state)
    }
}

private fun DrawScope.drawGroundShadow(s: Float, air: Float) {
    withTransform({ scale(s, s, Offset.Zero) }) {
        val w = 78f - air * 28f
        val c = Offset(50f, 98f)
        drawOval(
            brush = Brush.radialGradient(
                listOf(Color(0x5228466E).copy(alpha = 0.32f * (1f - air * 0.55f)), Color.Transparent),
                center = c,
                radius = w / 2f,
            ),
            topLeft = Offset(c.x - w / 2f, c.y - 4.5f),
            size = Size(w, 9f),
        )
    }
}

/** Body, shading and fur drawn once into a bitmap covering box units -5..105. */
private const val ART_PX = 640
private const val ART_SPAN = 110f
private const val ART_PAD = 5f

private fun bakeBody(path: Path, fur: FurStrokes, base: Color): ImageBitmap {
    val bmp = ImageBitmap(ART_PX, ART_PX)
    val k = ART_PX / ART_SPAN
    CanvasDrawScope().draw(Density(1f), LayoutDirection.Ltr, GfxCanvas(bmp), Size(ART_PX.toFloat(), ART_PX.toFloat())) {
        withTransform({
            scale(k, k, Offset.Zero)
            translate(ART_PAD, ART_PAD)
        }) {
            val fine = 0.5f
            // fuzzy silhouette: darker strands behind the body, lighter wisps over its edge
            drawPoints(fur.rim, PointMode.Lines, shadeColor(base, 0.82f), 0.75f, StrokeCap.Round)
            drawPath(path, base)
            drawPath(path, Brush.radialGradient(listOf(Color.White.copy(alpha = 0.34f), Color.Transparent),
                center = Offset(38f, 38f), radius = 58f))
            drawPath(path, Brush.radialGradient(
                0.55f to Color.Transparent, 1f to Color.Black.copy(alpha = 0.30f),
                center = Offset(50f, 62f), radius = 56f))
            drawPath(path, Brush.verticalGradient(
                0.7f to Color.Transparent, 1f to Color.Black.copy(alpha = 0.16f), startY = 15f, endY = 98f))
            drawPoints(fur.light, PointMode.Lines, Color.White.copy(alpha = 0.10f), fine, StrokeCap.Round)
            drawPoints(fur.dark, PointMode.Lines, Color.Black.copy(alpha = 0.07f), fine, StrokeCap.Round)
            drawPoints(fur.rim, PointMode.Lines, base.copy(alpha = 0.35f), fine, StrokeCap.Round)
        }
    }
    return bmp
}

private fun DrawScope.drawBody(
    path: Path,
    bodyArt: ImageBitmap,
    cosY: Float,
    pose: BotPose,
    state: BotState,
    style: BotStyle,
    base: Color,
) {
    withTransform({
        translate(-ART_PAD, -ART_PAD)
        scale(ART_SPAN / ART_PX, ART_SPAN / ART_PX, Offset.Zero)
    }) {
        drawImage(bodyArt, filterQuality = FilterQuality.Medium)
    }

    val frontness = ((cosY - 0.1f) / 0.4f).coerceIn(0f, 1f)
    if (frontness < 1f) {
        drawPath(path, Color.Black.copy(alpha = 0.14f * (1f - frontness)))
    }
    if (frontness > 0f) drawFaces(pose, state, style, cosY, frontness)
}

/** Same pinning maths as the web version: the anchor turns with the head. */
private fun DrawScope.drawFeather(bmp: androidx.compose.ui.graphics.ImageBitmap, pose: BotPose, anchor: Offset) {
    val px = anchor.x - CENTRE.x
    val py = anchor.y - CENTRE.y
    val pz = 6f
    val x1 = px * cos(pose.yaw) + pz * sin(pose.yaw)
    val z1 = -px * sin(pose.yaw) + pz * cos(pose.yaw)
    val y2 = py * cos(pose.pitch) - z1 * sin(pose.pitch)
    val z2 = py * sin(pose.pitch) + z1 * cos(pose.pitch)
    if (z2 <= -4f) return
    val x3 = x1 * cos(pose.roll) - y2 * sin(pose.roll)
    val y3 = x1 * sin(pose.roll) + y2 * cos(pose.roll)
    val at = Offset(CENTRE.x + x3, CENTRE.y + y3)
    val angle = pose.roll * 180f / PI.toFloat() + pose.swing
    withTransform({
        translate(at.x, at.y)
        rotate(angle, Offset.Zero)
    }) {
        drawImage(
            bmp,
            srcOffset = IntOffset.Zero,
            srcSize = IntSize(bmp.width, bmp.height),
            dstOffset = IntOffset(-4, -44),
            dstSize = IntSize(48, 48),
        )
    }
}
