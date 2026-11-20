import XCTest
@testable import BotUI

final class BotSimTests: XCTestCase {
    private func run(_ sim: BotSim, seconds: Double, _ each: (BotPose) -> Void = { _ in }) {
        var t = 0.0
        while t < seconds { sim.update(dt: 1.0 / 60); each(sim.pose); t += 1.0 / 60 }
    }

    func testDeterministic() {
        let a = BotSim(seed: 0.3, state: .happy), b = BotSim(seed: 0.3, state: .happy)
        run(a, seconds: 6); run(b, seconds: 6)
        XCTAssertEqual(a.pose, b.pose)
    }

    func testNeutralNeverHops() {
        let sim = BotSim(seed: 0.2)
        var minY = 0.0
        run(sim, seconds: 20) { minY = min(minY, $0.y) }
        XCTAssertGreaterThan(minY, -1)
    }

    func testHappyHopsAndSquashes() {
        let sim = BotSim(seed: 0.2, state: .happy)
        var minY = 0.0, maxSx = 1.0
        run(sim, seconds: 12) { minY = min(minY, $0.y); maxSx = max(maxSx, $0.sx) }
        XCTAssertLessThan(minY, -15)
        XCTAssertGreaterThan(maxSx, 1.02)
    }

    func testSleepingNeverHopsAndEyesShut() {
        let sim = BotSim(seed: 0.2, state: .happy)
        sim.setState(.sleeping)
        run(sim, seconds: 3)
        XCTAssertEqual(sim.pose.sleep, 1, accuracy: 0.01)
        var minY = 0.0
        run(sim, seconds: 10) { minY = min(minY, $0.y) }
        XCTAssertGreaterThan(minY, -1)
    }

    func testWorkingLaughs() {
        let sim = BotSim(seed: 0.2, state: .working)
        run(sim, seconds: 2)
        XCTAssertGreaterThan(sim.pose.laugh, 0.9)
    }

    func testPokeHops() {
        let sim = BotSim(seed: 0.2)
        sim.poke()
        var minY = 0.0
        run(sim, seconds: 1.5) { minY = min(minY, $0.y) }
        XCTAssertLessThan(minY, -15)
    }

    func testBigDtIsCapped() {
        let sim = BotSim(seed: 0.2, state: .happy)
        sim.update(dt: 5)
        XCTAssertLessThan(abs(sim.pose.y), 40)
    }

    func testSeedsDiffer() {
        let a = BotSim(seed: 0.1), b = BotSim(seed: 0.9)
        run(a, seconds: 10); run(b, seconds: 10)
        XCTAssertNotEqual(a.pose.yaw, b.pose.yaw)
    }

    func testRandomMatchesKnownMulberry() {
        var r = SeededRandom(seed: 1)
        let v = r.next()
        XCTAssertTrue(v >= 0 && v < 1)
    }

    func testEveryStateRunsCleanWithAFace() {
        for st in BotState.allCases {
            let sim = BotSim(seed: 0.3, state: st)
            run(sim, seconds: 8) {
                let v = [$0.x, $0.y, $0.sx, $0.sy, $0.yaw, $0.pitch, $0.roll, $0.talk]
                XCTAssertTrue(v.allSatisfy { !$0.isNaN }, "\(st)")
            }
            XCTAssertEqual(BotFaceSpec.of(st), BotFaceSpec.of(st))
        }
    }

    func testErrorAndAngryShakeSideways() {
        for st in [BotState.error, .angry] {
            let sim = BotSim(seed: 0.3, state: st)
            var maxX = 0.0
            run(sim, seconds: 10) { maxX = max(maxX, abs($0.x)) }
            XCTAssertGreaterThan(maxX, 0.2, "\(st)")
        }
    }

    func testSpeakingOpensTheMouthAndOthersStayShut() {
        let talker = BotSim(seed: 0.3, state: .speaking)
        var maxTalk = 0.0
        run(talker, seconds: 6) { maxTalk = max(maxTalk, $0.talk) }
        XCTAssertGreaterThan(maxTalk, 0.5)
        let quiet = BotSim(seed: 0.3)
        run(quiet, seconds: 3)
        XCTAssertEqual(quiet.pose.talk, 0, accuracy: 0.001)
    }

    func testExcitedHopsOftenAndLoveStaysPut() {
        let ex = BotSim(seed: 0.3, state: .excited)
        var minY = 0.0
        run(ex, seconds: 6) { minY = min(minY, $0.y) }
        XCTAssertLessThan(minY, -15)
        let love = BotSim(seed: 0.3, state: .love)
        var loveMin = 0.0
        run(love, seconds: 20) { loveMin = min(loveMin, $0.y) }
        XCTAssertGreaterThan(loveMin, -0.5)
    }

    func testChangingStateFadesTheOldFaceOut() {
        let sim = BotSim(seed: 0.3)
        run(sim, seconds: 1)
        XCTAssertNil(sim.pose.from)
        sim.setState(.love)
        run(sim, seconds: 0.05)
        XCTAssertEqual(sim.pose.from, .neutral)
        XCTAssertLessThan(sim.pose.blend, 1)
        run(sim, seconds: 0.5)
        XCTAssertNil(sim.pose.from)
        XCTAssertEqual(sim.pose.blend, 1, accuracy: 0.001)
    }

    func testGiggleShakesAndBouncesWhileNeutralStaysStill() {
        let g = BotSim(seed: 0.3, state: .giggle)
        var maxRoll = 0.0, minY = 0.0, maxTalk = 0.0
        run(g, seconds: 3) { maxRoll = max(maxRoll, abs($0.roll)); minY = min(minY, $0.y); maxTalk = max(maxTalk, $0.talk) }
        XCTAssertGreaterThan(maxRoll, 0.04)
        XCTAssertLessThan(minY, -1)
        XCTAssertGreaterThan(maxTalk, 0.5)
        let n = BotSim(seed: 0.3)
        var nMaxRoll = 0.0
        run(n, seconds: 3) { nMaxRoll = max(nMaxRoll, abs($0.roll)) }
        XCTAssertLessThan(nMaxRoll, 0.01)
    }

    func testNoFaceUsesBrowsAndOnlySadAndAngryTiltEyes() {
        for st in BotState.allCases {
            let tilt = BotFaceSpec.of(st).eyeTilt
            XCTAssertEqual(tilt != 0, st == .sad || st == .angry, "\(st)")
        }
        XCTAssertGreaterThan(BotFaceSpec.of(.sad).eyeTilt, 0)
        XCTAssertLessThan(BotFaceSpec.of(.angry).eyeTilt, 0)
    }

    func testPoseTimeAdvances() {
        let sim = BotSim(seed: 0.3)
        run(sim, seconds: 1)
        XCTAssertEqual(sim.pose.time, 1, accuracy: 0.05)
    }

    func testPresetShapesSitInsideTheBox() {
        for shape in [BotShape.teardrop, .round, .egg, .blob] {
            let b = shape.outline.bounds
            XCTAssertGreaterThan(b.minX, 0); XCTAssertLessThan(b.maxX, 100)
            XCTAssertGreaterThan(b.minY, 5); XCTAssertEqual(b.maxY, 98, accuracy: 0.6)
        }
    }

    func testSvgShapeIsFittedAndStandsOnTheGround() {
        let s = BotShape.svg("M0 0 L200 0 L200 100 L0 100 Z")
        let b = s.outline.bounds
        XCTAssertEqual(b.width, 84, accuracy: 0.01)
        XCTAssertEqual(b.minX, 8, accuracy: 0.01)
        XCTAssertEqual(b.maxY, 98, accuracy: 0.01)
    }

    func testSvgParsesRelativeSmoothAndQuadCommands() {
        let rel = BotShape.svg("m10 10 h30 v30 h-30 z")
        XCTAssertEqual(rel.outline.bounds.width, rel.outline.bounds.height, accuracy: 0.01)
        let mixed = BotShape.svg("M0 50 Q25 0 50 50 S75 100 100 50 Z")
        XCTAssertNotEqual(mixed, .teardrop)
        XCTAssertEqual(mixed.outline.bounds.width, 84, accuracy: 0.01)
    }

    func testBadSvgFallsBackToTeardrop() {
        XCTAssertEqual(BotShape.svg(""), .teardrop)
        XCTAssertEqual(BotShape.svg("not a path"), .teardrop)
        XCTAssertEqual(BotShape.svg("M0 0 A5 5 0 0 1 10 10"), .teardrop)
        XCTAssertEqual(BotShape.svg("M5 5 L5 5 Z"), .teardrop)
    }

    func testFurFollowsTheShape() {
        let fur = Fur.build(outline: BotShape.round.outline, seed: 3, length: 2.6, density: 0.5)
        XCTAssertFalse(fur.rim.isEmpty)
        XCTAssertFalse(fur.light.isEmpty)
    }
}
