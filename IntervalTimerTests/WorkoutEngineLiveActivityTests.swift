import Foundation
import Testing
@testable import IntervalTimer

@MainActor
final class SpyLiveActivity: LiveActivityUpdating {
	typealias State = WorkoutActivityAttributes.ContentState

	var started: [State] = []
	var updates: [State] = []
	var ended: [(state: State, immediately: Bool)] = []

	func start(_ state: State) { started.append(state) }
	func update(_ state: State) { updates.append(state) }
	func end(_ state: State, immediately: Bool) { ended.append((state, immediately)) }
}

@MainActor
struct WorkoutEngineLiveActivityTests {
	let clock = FakeClock()
	let player = SpyCuePlayer()
	let activity = SpyLiveActivity()
	let config = WorkoutConfig(warmUp: 60, work: 30, rest: 15, intervals: 2)

	func makeEngine() -> WorkoutEngine {
		let clock = self.clock
		return WorkoutEngine(cuePlayer: player, liveActivity: activity, tickInterval: nil, now: { clock.now })
	}

	func run(_ engine: WorkoutEngine, for seconds: Int) {
		for _ in 0..<seconds {
			clock.advance(1)
			engine.tick()
		}
	}

	@Test func shouldStartLiveActivityInWarmUpWhenWorkoutStarts() throws {
		let engine = makeEngine()
		let startTime = clock.now
		engine.start(config: config)
		let state = try #require(activity.started.first)
		#expect(activity.started.count == 1)
		#expect(state.phase == .warmUp)
		#expect(state.intervalNumber == 0)
		#expect(state.totalIntervals == 2)
		#expect(state.phaseStart == startTime)
		#expect(state.phaseEnd == startTime.addingTimeInterval(60))
		#expect(!state.isPaused)
	}

	@Test func shouldOnlyUpdateLiveActivityWhenPhaseChanges() throws {
		let engine = makeEngine()
		let startTime = clock.now
		engine.start(config: config)
		run(engine, for: 59)
		#expect(activity.updates.isEmpty)
		run(engine, for: 1)
		let state = try #require(activity.updates.last)
		#expect(activity.updates.count == 1)
		#expect(state.phase == .work)
		#expect(state.intervalNumber == 1)
		#expect(state.phaseStart == startTime.addingTimeInterval(60))
		#expect(state.phaseEnd == startTime.addingTimeInterval(90))
	}

	@Test func shouldFreezeRemainingTimeInLiveActivityWhenPaused() throws {
		let engine = makeEngine()
		engine.start(config: config)
		run(engine, for: 10)
		engine.pause()
		let state = try #require(activity.updates.last)
		#expect(state.pausedRemaining == 50)
	}

	@Test func shouldShiftPhaseEndByPausedTimeOnResume() throws {
		let engine = makeEngine()
		engine.start(config: config)
		run(engine, for: 10)
		engine.pause()
		clock.advance(300)
		let resumeTime = clock.now
		engine.resume()
		let state = try #require(activity.updates.last)
		#expect(state.pausedRemaining == nil)
		#expect(state.phaseEnd == resumeTime.addingTimeInterval(50))
	}

	@Test func shouldEndLiveActivityImmediatelyOnStop() throws {
		let engine = makeEngine()
		engine.start(config: config)
		engine.stop()
		let end = try #require(activity.ended.first)
		#expect(activity.ended.count == 1)
		#expect(end.immediately)
	}

	@Test func shouldEndLiveActivityWithFinishedStateWhenWorkoutCompletes() throws {
		let engine = makeEngine()
		engine.start(config: config)
		run(engine, for: 135)
		let end = try #require(activity.ended.first)
		#expect(activity.ended.count == 1)
		#expect(end.state.isFinished)
		#expect(!end.immediately)
	}

	@Test func shouldNotEndLiveActivityAgainWhenDoneIsTappedAfterFinish() {
		let engine = makeEngine()
		engine.start(config: config)
		run(engine, for: 135)
		engine.stop()
		#expect(activity.ended.count == 1)
	}

	@Test func shouldUseGetReadyPhaseWhenWarmUpIsZero() throws {
		let engine = makeEngine()
		engine.start(config: WorkoutConfig(warmUp: 0, work: 30, rest: 15, intervals: 1))
		#expect(try #require(activity.started.first).phase == .getReady)
	}
}
