package dev.botui

import kotlin.math.PI
import kotlin.math.abs
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class BotSimTest {
    private fun run(sim: BotSim, seconds: Float, step: Float = 1f / 60f, each: (BotPose) -> Unit = {}) {
        var t = 0f
        while (t < seconds) { sim.update(step); each(sim.pose); t += step }
    }

    @Test fun sameSeedPlaysTheSame() {
        val a = BotSim(0.23f, BotState.Happy)
        val b = BotSim(0.23f, BotState.Happy)
        run(a, 10f); run(b, 10f)
        assertEquals(a.pose, b.pose)
    }

    @Test fun differentSeedsDiffer() {
        val a = BotSim(0.1f, BotState.Happy)
        val b = BotSim(0.9f, BotState.Happy)
        run(a, 6f); run(b, 6f)
        assertTrue(a.pose != b.pose)
    }

    @Test fun neutralNeverHops() {
        val sim = BotSim(0.11f, BotState.Neutral)
        var minY = 0f
        run(sim, 40f) { minY = minOf(minY, it.y) }
        assertEquals(0f, minY, 0.5f)
    }

    @Test fun happyHopsAndSpinsAFullTurn() {
        val sim = BotSim(0.23f, BotState.Happy)
        var minY = 0f
        var maxYaw = 0f
        run(sim, 12f) { minY = minOf(minY, it.y); maxYaw = maxOf(maxYaw, abs(it.yaw)) }
        assertTrue("hop height $minY", minY < -15f && minY > -40f)
        assertTrue("spin $maxYaw", maxYaw > PI.toFloat())
    }

    @Test fun squashesOnTakeOffAndLanding() {
        val sim = BotSim(0.23f, BotState.Happy)
        var minSy = 1f
        var maxSy = 1f
        run(sim, 12f) { minSy = minOf(minSy, it.sy); maxSy = maxOf(maxSy, it.sy) }
        assertTrue(minSy < 0.9f)
        assertTrue(maxSy > 1.05f)
    }

    @Test fun sleepingNeverHopsAndKeepsEyesShut() {
        val sim = BotSim(0.84f, BotState.Sleeping)
        var minY = 99f
        run(sim, 20f) { minY = minOf(minY, it.y) }
        assertTrue(minY >= 0f)
        assertEquals(1f, sim.pose.sleep, 0.01f)
    }

    @Test fun blinksHappenAndStayInRange() {
        val sim = BotSim(0.11f, BotState.Neutral)
        var blinked = false
        run(sim, 20f) {
            assertTrue(it.blink in 0f..1f)
            if (it.blink > 0.5f) blinked = true
        }
        assertTrue(blinked)
    }

    @Test fun movingToWorkingClosesEyesIntoALaugh() {
        val sim = BotSim(0.05f, BotState.Neutral)
        run(sim, 1f)
        assertEquals(0f, sim.pose.laugh, 0.01f)
        sim.setState(BotState.Working)
        run(sim, 2f)
        assertTrue(sim.pose.laugh > 0.95f)
    }

    @Test fun featherSwingIsBounded() {
        val sim = BotSim(0.23f, BotState.Happy)
        run(sim, 30f) { assertTrue(abs(it.swing) < 40f) }
    }

    @Test fun hugeFrameGapIsCapped() {
        val sim = BotSim(0.2f, BotState.Happy)
        sim.update(5f)
        assertFalse(sim.pose.y.isNaN())
    }

    @Test fun pokeStartsAHop() {
        val sim = BotSim(0.5f, BotState.Neutral)
        sim.poke()
        var minY = 0f
        run(sim, 1.5f) { minY = minOf(minY, it.y) }
        assertTrue(minY < -15f)
    }

    @Test fun everyStateRunsCleanWithAFace() {
        for (st in BotState.entries) {
            val sim = BotSim(0.3f, st)
            run(sim, 8f) {
                val all = listOf(it.x, it.y, it.sx, it.sy, it.yaw, it.pitch, it.roll, it.talk, it.swing)
                assertTrue("$st NaN", all.none { v -> v.isNaN() })
            }
            assertTrue(BotFaceSpec.of(st) != null)
        }
    }

    @Test fun errorAndAngryShakeSideways() {
        for (st in listOf(BotState.Error, BotState.Angry)) {
            val sim = BotSim(0.3f, st)
            var maxX = 0f
            run(sim, 10f) { maxX = maxOf(maxX, abs(it.x)) }
            assertTrue("$st shake $maxX", maxX > 0.2f)
        }
    }

    @Test fun speakingOpensTheMouthAndOthersStayShut() {
        val talker = BotSim(0.3f, BotState.Speaking)
        var maxTalk = 0f
        run(talker, 6f) { maxTalk = maxOf(maxTalk, it.talk) }
        assertTrue(maxTalk > 0.5f)
        val quiet = BotSim(0.3f, BotState.Neutral)
        run(quiet, 3f)
        assertEquals(0f, quiet.pose.talk, 0.001f)
    }

    @Test fun excitedHopsOftenAndLoveStaysPut() {
        val ex = BotSim(0.3f, BotState.Excited)
        var minY = 0f
        run(ex, 6f) { minY = minOf(minY, it.y) }
        assertTrue(minY < -15f)
        val love = BotSim(0.3f, BotState.Love)
        var loveMin = 0f
        run(love, 20f) { loveMin = minOf(loveMin, it.y) }
        assertEquals(0f, loveMin, 0.5f)
    }

    @Test fun changingStateFadesTheOldFaceOut() {
        val sim = BotSim(0.3f, BotState.Neutral)
        run(sim, 1f)
        assertEquals(null, sim.pose.from)
        sim.setState(BotState.Love)
        run(sim, 0.05f)
        assertEquals(BotState.Neutral, sim.pose.from)
        assertTrue(sim.pose.blend < 1f)
        run(sim, 0.5f)
        assertEquals(null, sim.pose.from)
        assertEquals(1f, sim.pose.blend, 0.001f)
    }

    @Test fun giggleShakesAndBouncesWhileNeutralStaysStill() {
        val g = BotSim(0.3f, BotState.Giggle)
        var maxRoll = 0f; var minY = 0f; var maxTalk = 0f
        run(g, 3f) { maxRoll = maxOf(maxRoll, kotlin.math.abs(it.roll)); minY = minOf(minY, it.y); maxTalk = maxOf(maxTalk, it.talk) }
        assertTrue(maxRoll > 0.03f)
        assertTrue(minY < -1f)
        assertTrue(maxTalk > 0.5f)
        val n = BotSim(0.3f, BotState.Neutral)
        var nMinY = 0f
        run(n, 3f) { nMinY = minOf(nMinY, it.y) }
        assertTrue(nMinY > -1f)
    }

    @Test fun onlyThinkingAndIdeaCarryABadge() {
        val badged = BotState.values().filter { BotBadge.of(it) != BotBadge.None }
        assertEquals(listOf(BotState.Thinking, BotState.Idea), badged)
    }

}
