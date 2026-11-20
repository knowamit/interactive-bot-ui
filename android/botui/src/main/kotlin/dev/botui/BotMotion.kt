package dev.botui

/** How the body moves in a state. Numbers feed the sim; the face comes from [BotFaceSpec]. */
internal data class BotMotion(
    /** + lifts the face, - lets it droop. Radians. */
    val pitch: Float = 0f,
    val roll: Float = 0f,
    val y: Float = 0f,
    /** Seconds between hops; 0 = none. */
    val jumpEvery: Float = 0f,
    /** Sideways tremble in body units, in bursts. */
    val shake: Float = 0f,
    /** Gentle up and down nod, radians. */
    val nod: Float = 0f,
    /** Heartbeat squash, fraction of size. */
    val pulse: Float = 0f,
    /** Quick side to side tilt, radians (a giggle). */
    val wiggle: Float = 0f,
    /** Small rapid bounces in place, body units. */
    val bounce: Float = 0f,
    /** Stops random head turns; the eyes still glance. */
    val holdHead: Boolean = false,
) {
    companion object {
        fun of(state: BotState): BotMotion = when (state) {
            BotState.Neutral -> BotMotion()
            BotState.Happy -> BotMotion(jumpEvery = 2.5f)
            BotState.Working -> BotMotion(pitch = 0.087f, jumpEvery = 2.5f)
            BotState.Sleeping -> BotMotion(pitch = -0.28f, roll = 0.105f, y = 3f)
            BotState.Thinking -> BotMotion(roll = -0.12f, holdHead = true)
            BotState.Idea -> BotMotion(pitch = 0.05f, jumpEvery = 3f)
            BotState.Love -> BotMotion(pulse = 0.045f)
            BotState.Sad -> BotMotion(pitch = -0.14f, y = 2f, holdHead = true)
            BotState.Surprised -> BotMotion(pitch = 0.06f, jumpEvery = 4f)
            BotState.Angry -> BotMotion(pitch = -0.04f, shake = 0.7f, holdHead = true)
            BotState.Confused -> BotMotion(roll = 0.14f)
            BotState.Excited -> BotMotion(jumpEvery = 1.4f)
            BotState.Listening -> BotMotion(roll = 0.1f, nod = 0.04f, holdHead = true)
            BotState.Speaking -> BotMotion(nod = 0.03f)
            BotState.Success -> BotMotion(jumpEvery = 1.8f)
            BotState.Error -> BotMotion(pitch = -0.05f, shake = 1.2f, holdHead = true)
            BotState.Giggle -> BotMotion(pitch = 0.04f, wiggle = 0.07f, bounce = 2.2f)
        }
    }
}
