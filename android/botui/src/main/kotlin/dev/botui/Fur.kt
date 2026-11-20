package dev.botui

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathMeasure
import androidx.compose.ui.graphics.vector.PathParser
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.sin

/** BotUI's teardrop outline, in the 100 x 100 body box. */
internal const val BODY_SVG =
    "M50 15C67.6 15 80.8 35 89.6 55C97.3 71 94 98 50 98C6 98 2.7 71 10.4 55C19.2 35 32.4 15 50 15Z"

internal fun bodyPath(): Path = PathParser().parsePathString(BODY_SVG).toPath()

/** Fur strokes in body units, as flat start/end pairs ready for drawPoints(Lines). */
internal class FurStrokes(
    val rim: List<Offset>,
    val light: List<Offset>,
    val dark: List<Offset>,
)

internal object Fur {
    private const val CENTER_X = 50f
    private const val CENTER_Y = 60f

    fun build(path: Path, seed: Int, length: Float, density: Float): FurStrokes {
        if (length <= 0f || density <= 0f) return FurStrokes(emptyList(), emptyList(), emptyList())
        val rng = SeededRandom(seed)
        val contour = sampleContour(path, 240)
        return FurStrokes(
            rim = rimStrokes(contour, rng, (1500 * density).toInt(), length),
            light = interior(contour, rng, (1700 * density).toInt(), length * 0.7f),
            dark = interior(contour, rng, (1300 * density).toInt(), length * 0.7f),
        )
    }

    private fun sampleContour(path: Path, n: Int): List<Offset> {
        val m = PathMeasure().apply { setPath(path, true) }
        val total = m.length
        return List(n) { m.getPosition(total * it / n) }
    }

    private fun rimStrokes(c: List<Offset>, rng: SeededRandom, count: Int, length: Float): List<Offset> {
        val out = ArrayList<Offset>(count * 2)
        repeat(count) {
            val i = (rng.next() * c.size).toInt().coerceAtMost(c.size - 1)
            val p = c[i]
            val q = c[(i + 1) % c.size]
            val tx = q.x - p.x
            val ty = q.y - p.y
            val tl = hypot(tx, ty).coerceAtLeast(1e-3f)
            // outward normal: away from the body's middle
            var nx = ty / tl
            var ny = -tx / tl
            if (nx * (p.x - CENTER_X) + ny * (p.y - CENTER_Y) < 0f) { nx = -nx; ny = -ny }
            val a = atan2(ny, nx) + rng.range(-0.5f, 0.5f)
            val len = length * rng.range(0.4f, 1.0f)
            val dx = cos(a) * len
            val dy = sin(a) * len + len * 0.25f // gravity
            out += Offset(p.x - dx * 0.4f, p.y - dy * 0.4f)
            out += Offset(p.x + dx, p.y + dy)
        }
        return out
    }

    private fun interior(c: List<Offset>, rng: SeededRandom, count: Int, length: Float): List<Offset> {
        val out = ArrayList<Offset>(count * 2)
        var guard = 0
        val box = Offset(c.minOf { it.x }, c.minOf { it.y }).let { lo ->
            androidx.compose.ui.geometry.Rect(lo, Offset(c.maxOf { it.x }, c.maxOf { it.y }))
        }
        while (out.size < count * 2 && guard++ < count * 8) {
            val p = Offset(rng.range(box.left, box.right), rng.range(box.top, box.bottom))
            if (!inside(c, p)) continue
            // strands fan out from the middle, pulled down by gravity
            val a = atan2(p.y - CENTER_Y, p.x - CENTER_X) + rng.range(-0.7f, 0.7f)
            val len = length * rng.range(0.6f, 1.2f)
            val dx = cos(a) * len
            val dy = sin(a) * len + len * 0.45f
            out += p
            out += Offset(p.x + dx, p.y + dy)
        }
        return out
    }

    private fun inside(poly: List<Offset>, p: Offset): Boolean {
        var hit = false
        var j = poly.size - 1
        for (i in poly.indices) {
            val a = poly[i]
            val b = poly[j]
            if ((a.y > p.y) != (b.y > p.y) &&
                p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x
            ) hit = !hit
            j = i
        }
        return hit
    }
}
