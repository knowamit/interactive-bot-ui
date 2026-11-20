package dev.botui

import androidx.compose.ui.graphics.Matrix
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.vector.PathParser
import kotlin.math.min

/**
 * Body outline. Presets are drawn for the face to sit right. [svg] takes any
 * SVG path string (`M L H V C Q Z`, any units): it is scaled to fit and put on the ground.
 */
class BotShape private constructor(internal val svg: String, internal val fit: Boolean) {
    override fun equals(other: Any?) = other is BotShape && other.svg == svg && other.fit == fit
    override fun hashCode() = svg.hashCode() * 31 + fit.hashCode()

    companion object {
        val Teardrop = BotShape(BODY_SVG, false)
        val Round = BotShape(
            "M50 14C73.2 14 92 32.8 92 56C92 79.2 73.2 98 50 98C26.8 98 8 79.2 8 56C8 32.8 26.8 14 50 14Z", false)
        val Egg = BotShape(
            "M50 12C68 12 78 36 86 58C92 75 80 98 50 98C20 98 8 75 14 58C22 36 32 12 50 12Z", false)
        val Blob = BotShape(
            "M26 20C40 14 60 14 74 20C90 27 94 50 92 70C90 90 76 98 50 98C24 98 10 90 8 70C6 50 10 27 26 20Z", false)

        /** Soft six-petal flower, like the OpenAI mark. */
        val Blossom = BotShape(
            "M50.0 0.0C52.1 0.0 54.4 0.7 56.4 1.7C58.3 2.8 60.1 4.6 61.8 6.1C63.4 7.6 64.7 9.6 66.2 11.0C67.6 12.4 68.9 13.7 70.5 14.6C72.0 15.5 73.8 15.9 75.7 16.5C77.7 17.0 80.0 17.2 82.1 17.9C84.3 18.5 86.8 19.2 88.6 20.4C90.5 21.6 92.2 23.2 93.3 25.0C94.4 26.8 94.9 29.2 95.0 31.4C95.1 33.6 94.4 36.1 93.9 38.2C93.4 40.4 92.4 42.5 91.9 44.5C91.4 46.4 90.9 48.2 90.9 50.0C90.9 51.8 91.4 53.6 91.9 55.5C92.4 57.5 93.4 59.6 93.9 61.8C94.4 63.9 95.1 66.4 95.0 68.6C94.9 70.8 94.4 73.2 93.3 75.0C92.2 76.8 90.5 78.4 88.6 79.6C86.8 80.8 84.3 81.5 82.1 82.1C80.0 82.8 77.7 83.0 75.7 83.5C73.8 84.1 72.0 84.5 70.5 85.4C68.9 86.3 67.6 87.6 66.2 89.0C64.7 90.4 63.4 92.4 61.8 93.9C60.1 95.4 58.3 97.2 56.4 98.3C54.4 99.3 52.1 100.0 50.0 100.0C47.9 100.0 45.6 99.3 43.6 98.3C41.7 97.2 39.9 95.4 38.2 93.9C36.6 92.4 35.3 90.4 33.8 89.0C32.4 87.6 31.1 86.3 29.5 85.4C28.0 84.5 26.2 84.1 24.3 83.5C22.3 83.0 20.0 82.8 17.9 82.1C15.7 81.5 13.2 80.8 11.4 79.6C9.5 78.4 7.8 76.8 6.7 75.0C5.6 73.2 5.1 70.8 5.0 68.6C4.9 66.4 5.6 63.9 6.1 61.8C6.6 59.6 7.6 57.5 8.1 55.5C8.6 53.6 9.1 51.8 9.1 50.0C9.1 48.2 8.6 46.4 8.1 44.5C7.6 42.5 6.6 40.4 6.1 38.2C5.6 36.1 4.9 33.6 5.0 31.4C5.1 29.2 5.6 26.8 6.7 25.0C7.8 23.2 9.5 21.6 11.4 20.4C13.2 19.2 15.7 18.5 17.9 17.9C20.0 17.2 22.3 17.0 24.3 16.5C26.2 15.9 28.0 15.5 29.5 14.6C31.1 13.7 32.4 12.4 33.8 11.0C35.3 9.6 36.6 7.6 38.2 6.1C39.9 4.6 41.7 2.8 43.6 1.7C45.6 0.7 47.9 -0.0 50.0 0.0Z", true)

        /** Rounded square, like a Grok tile. */
        val Squircle = BotShape(
            "M50 0C90 0 100 10 100 50C100 90 90 100 50 100C10 100 0 90 0 50C0 10 10 0 50 0Z", true)

        fun svg(path: String) = BotShape(path, true)
    }
}

private const val FIT_LEFT = 8f
private const val FIT_SPAN = 84f
private const val FIT_BOTTOM = 98f

/** Parses the outline; a bad or empty path falls back to the teardrop. */
internal fun BotShape.toPath(): Path {
    val raw = runCatching { PathParser().parsePathString(svg).toPath() }.getOrNull()
    val b = raw?.getBounds()
    if (raw == null || b == null || b.width < 1f || b.height < 1f) return bodyPath()
    if (!fit) return raw
    val k = min(FIT_SPAN / b.width, FIT_SPAN / b.height)
    val tx = FIT_LEFT + FIT_SPAN / 2f - k * (b.left + b.width / 2f)
    val ty = FIT_BOTTOM - k * b.bottom
    val m = Matrix(floatArrayOf(k, 0f, 0f, 0f, 0f, k, 0f, 0f, 0f, 0f, 1f, 0f, tx, ty, 0f, 1f))
    raw.transform(m)
    return raw
}
