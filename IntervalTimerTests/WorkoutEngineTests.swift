import Foundation
import Testing
@testable import IntervalTimer

@MainActor
final class FakeClock {
	var now = Date(timeIntervalSinceReferenceDate: 0)

	func advance(_ seconds: TimeInterval) {
		now = now.addingTimeInterval(seconds)
	}
}

@MainActor
final class SpyCuePlayer: CuePlaying {
	var played: [CueKind] = []
	var sessionActive = false

	func play(_ kind: CueKind) { played.append(kind) }
	func beginSession() { sessionActive = true }
	func endSession() { sessionActive = false }
}

@MainActor
struct WorkoutEngineTests {
	let clock = FakeClock()
	let player = SpyCuePlayer()
	let config = WorkoutConfig(warmUp: 60, work: 30, rest: 15, intervals: 2)

	func makeEngine() -> WorkoutEngine {
		let clock = self.clock
		return WorkoutEngine(cuePlayer: player, tickInterval: nil, now: { clock.now })
	}

	/// Advances in one-second steps so cues fire the way they would with a live timer.
	func run(_ engine: WorkoutEngine, for seconds: Int) {
		for _ in 0..<seconds {
			clock.advance(1)
			engine.tick()
		}
	}

	@Test func shouldBeIdleBeforeStart() {
		let engine = makeEngine()
		#expect(engine.state == .idle)
		#expect(engine.currentPhase == nil)
	}

	@Test func shouldBeginInWarmUpWithFullPhaseRemainingAndAudioSessionActive() {
		let engine = makeEngine()
		engine.start(config: config)
		#expect(engine.state == .running)
		#expect(engine.currentPhase?.kind == .warmUp)
		#expect(engine.phaseRemaining == 60)
		#expect(engine.phaseProgress == 0)
		#expect(player.sessionActive)
	}

	@Test func shouldReportRemainingTimeAndProgressWithinPhase() {
		let engine = makeEngine()
		engine.start(config: config)
		clock.advance(15.4)
		engine.tick()
		// Rounds up so the display reads 45 until the 45th second has fully elapsed.
		#expect(engine.phaseRemaining == 45)
		#expect(abs(engine.phaseProgress - 15.4 / 60) < 0.0001)
	}

	@Test func shouldPlayCountdownThenIntervalStartAtEndOfWarmUp() {
		let engine = makeEngine()
		engine.start(config: config)
		run(engine, for: 56)
		#expect(player.played.isEmpty)
		run(engine, for: 4)
		#expect(player.played == [.countdown, .countdown, .countdown, .intervalStart])
		#expect(engine.currentPhase?.kind == .work(number: 1))
		#expect(engine.intervalNumber == 1)
		#expect(engine.totalIntervals == 2)
	}

	@Test func shouldPlayEveryCueInOrderAndFinish() {
		let engine = makeEngine()
		engine.start(config: config)
		run(engine, for: 135)
		#expect(player.played == [
			.countdown, .countdown, .countdown, .intervalStart, .intervalEnd,
			.countdown, .countdown, .countdown, .intervalStart, .finish,
		])
		#expect(engine.state == .finished)
		#expect(engine.currentPhase == nil)
		#expect(!player.sessionActive)
	}

	@Test func shouldKeepShowingLatestIntervalNumberDuringRest() {
		let engine = makeEngine()
		engine.start(config: config)
		run(engine, for: 95)
		#expect(engine.currentPhase?.kind == .rest(number: 1))
		#expect(engine.intervalNumber == 1)
	}

	@Test func shouldShowIntervalZeroDuringWarmUp() {
		let engine = makeEngine()
		engine.start(config: config)
		#expect(engine.intervalNumber == 0)
	}

	@Test func shouldFreezeTimeWhilePaused() {
		let engine = makeEngine()
		engine.start(config: config)
		run(engine, for: 10)
		engine.pause()
		#expect(engine.state == .paused)
		clock.advance(300)
		engine.tick()
		#expect(engine.phaseRemaining == 50)
		#expect(player.played.isEmpty)
	}

	@Test func shouldContinueFromSamePointAfterResume() {
		let engine = makeEngine()
		engine.start(config: config)
		run(engine, for: 10)
		engine.pause()
		clock.advance(300)
		engine.resume()
		run(engine, for: 5)
		#expect(engine.state == .running)
		#expect(engine.phaseRemaining == 45)
	}

	@Test func shouldResetToIdleAndEndAudioSessionOnStop() {
		let engine = makeEngine()
		engine.start(config: config)
		run(engine, for: 70)
		engine.stop()
		#expect(engine.state == .idle)
		#expect(engine.currentPhase == nil)
		#expect(!player.sessionActive)
	}

	@Test func shouldPauseWhenAudioIsInterrupted() {
		let engine = makeEngine()
		engine.start(config: config)
		engine.handleInterruption()
		#expect(engine.state == .paused)
	}

	@Test func shouldIgnoreInterruptionWhenNotRunning() {
		let engine = makeEngine()
		engine.handleInterruption()
		#expect(engine.state == .idle)
	}

	@Test func shouldSkipStaleCuesAfterLongGapButStillReachCurrentPhase() {
		let engine = makeEngine()
		engine.start(config: config)
		// Simulates the app being suspended across the warm-up → work boundary.
		clock.advance(70)
		engine.tick()
		#expect(player.played.isEmpty)
		#expect(engine.currentPhase?.kind == .work(number: 1))
	}

	@Test func shouldStillPlayFinishWhenTickArrivesLate() {
		let engine = makeEngine()
		engine.start(config: config)
		run(engine, for: 134)
		player.played.removeAll()
		clock.advance(5)
		engine.tick()
		#expect(engine.state == .finished)
		#expect(player.played == [.finish])
	}

	@Test func shouldStartFifteenSecondGetReadyWhenWarmUpIsZero() {
		let engine = makeEngine()
		engine.start(config: WorkoutConfig(warmUp: 0, work: 30, rest: 15, intervals: 1))
		#expect(engine.currentPhase?.kind == .getReady)
		#expect(engine.phaseRemaining == 15)
		run(engine, for: 15)
		#expect(player.played == [.countdown, .countdown, .countdown, .intervalStart])
	}
}
