package dev.botui

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap

enum class BotFace { Eyes, EyesAndMouth }

/**
 * Everything you can customise. Colour and fur are independent of the mood
 * ([BotState]) so any colour works in any state.
 */
data class BotStyle(
    /** Body colour. */
    val color: Color = Color(0xFF8FD0FA),
    /** Eye and mouth colour. */
    val ink: Color = Color.White,
    val face: BotFace = BotFace.EyesAndMouth,
    /** Your own face. Replaces the state's preset face; the state still drives the motion. */
    val customFace: BotFaceSpec? = null,
    /** Body outline: a preset or your own SVG path. */
    val shape: BotShape = BotShape.Teardrop,
    /** 0.6 ... 1.6. Lightens or darkens the body colour. */
    val brightness: Float = 1.1f,
    /** Fur strand length in body units (the body is 100 tall). 0 turns fur off. */
    val furLength: Float = 2.6f,
    /** 0 ... 1 */
    val furDensity: Float = 0.75f,
    /** Optional ornament pinned to the crown. It turns and swings with the head. */
    val feather: ImageBitmap? = null,
    /** Overrides the hop interval for the current state; null keeps the state's default. */
    val jumpEverySeconds: Float? = null,
)
