package dev.botui

enum class BotEyes { Oval, ArcUp, ArcDown, Heart, Star, Cross, Slit }

enum class BotMouth { None, Smile, Grin, Open, O, Flat, Frown, Wavy, Dot, Talk }

/**
 * A whole face as plain numbers. Every named [BotState] is a preset of this,
 * and you can pass your own through [BotStyle.customFace] to build any state.
 */
data class BotFaceSpec(
    val eyes: BotEyes = BotEyes.Oval,
    val mouth: BotMouth = BotMouth.Smile,
    /** Eye size, 1 = normal. */
    val eyeScale: Float = 1f,
    /** Right eye size; null = same as [eyeScale]. */
    val eyeScaleRight: Float? = null,
    /** Extra gaze shift in face units, on top of the random glances. */
    val lookX: Float = 0f,
    val lookY: Float = 0f,
    val mouthScale: Float = 1f,
    /** Sideways mouth shift in body units. */
    val mouthShift: Float = 0f,
    /** Turns oval eyes: + sad (outer ends down), - angry (inner ends down). -1 ... 1 */
    val eyeTilt: Float = 0f,
) {
    companion object {
        fun of(state: BotState): BotFaceSpec = when (state) {
            BotState.Neutral, BotState.Happy -> BotFaceSpec()
            BotState.Working -> BotFaceSpec(BotEyes.ArcUp, BotMouth.Grin)
            BotState.Sleeping -> BotFaceSpec(BotEyes.ArcDown, BotMouth.Dot)
            BotState.Thinking -> BotFaceSpec(
                mouth = BotMouth.Flat, mouthScale = 0.7f, mouthShift = 4f, lookX = 1.2f, lookY = -1.4f,
            )
            BotState.Idea -> BotFaceSpec(
                mouth = BotMouth.Open, eyeScale = 1.2f, mouthScale = 0.8f, lookY = -1.2f,
            )
            BotState.Love -> BotFaceSpec(BotEyes.Heart, BotMouth.Smile)
            BotState.Sad -> BotFaceSpec(
                mouth = BotMouth.Frown, eyeScale = 0.9f, lookY = 1.4f, eyeTilt = 0.8f,
            )
            BotState.Surprised -> BotFaceSpec(mouth = BotMouth.O, eyeScale = 1.35f)
            BotState.Angry -> BotFaceSpec(
                BotEyes.Slit, BotMouth.Frown, eyeScale = 0.95f, eyeTilt = -1f,
            )
            BotState.Confused -> BotFaceSpec(
                mouth = BotMouth.Wavy, eyeScale = 0.85f, eyeScaleRight = 1.25f, lookX = 1f,
            )
            BotState.Excited -> BotFaceSpec(BotEyes.Star, BotMouth.Grin)
            BotState.Listening -> BotFaceSpec(eyeScale = 1.15f, mouthScale = 0.7f)
            BotState.Speaking -> BotFaceSpec(mouth = BotMouth.Talk)
            BotState.Success -> BotFaceSpec(BotEyes.ArcUp, BotMouth.Grin, mouthScale = 1.15f)
            BotState.Error -> BotFaceSpec(BotEyes.Cross, BotMouth.Wavy)
            BotState.Giggle -> BotFaceSpec(BotEyes.ArcUp, BotMouth.Talk, mouthScale = 1.3f)
        }
    }
}
