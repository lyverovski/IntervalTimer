import Testing
@testable import IntervalTimer

@MainActor
struct WorkoutScheduleTests {

	@Test func shouldStartWithWarmUpThenAlternateWorkAndRest() {
		let schedule = WorkoutSchedule(config: WorkoutConfig(warmUp: 60, work: 30, rest: 15, intervals: 2))
		#expect(schedule.phases == [
			Phase(kind: .warmUp, start: 0, duration: 60),
			Phase(kind: .work(number: 1), start: 60, duration: 30),
			Phase(kind: .rest(number: 1), start: 90, duration: 15),
			Phase(kind: .work(number: 2), start: 105, duration: 30),
		])
		#expect(schedule.duration == 135)
	}

	@Test func shouldUseFifteenSecondGetReadyPhaseWhenWarmUpIsZero() {
		let schedule = WorkoutSchedule(config: WorkoutConfig(warmUp: 0, work: 30, rest: 15, intervals: 1))
		#expect(schedule.phases == [
			Phase(kind: .getReady, start: 0, duration: 15),
			Phase(kind: .work(number: 1), start: 15, duration: 30),
		])
		#expect(schedule.duration == 45)
	}

	@Test func shouldCountDownBeforeEveryWorkIntervalButNotBeforeRest() {
		let schedule = WorkoutSchedule(config: WorkoutConfig(warmUp: 60, work: 30, rest: 15, intervals: 2))
		let countdownTimes = schedule.cues.filter { $0.kind == .countdown }.map(\.time)
		#expect(countdownTimes == [57, 58, 59, 102, 103, 104])
	}

	@Test func shouldPlayStartAndEndCuesAndFinishInsteadOfFinalEnd() {
		let schedule = WorkoutSchedule(config: WorkoutConfig(warmUp: 60, work: 30, rest: 15, intervals: 2))
		let boundaryCues = schedule.cues.filter { $0.kind != .countdown }
		#expect(boundaryCues == [
			Cue(time: 60, kind: .intervalStart),
			Cue(time: 90, kind: .intervalEnd),
			Cue(time: 105, kind: .intervalStart),
			Cue(time: 135, kind: .finish),
		])
	}

	@Test func shouldOrderAllCuesChronologically() {
		let schedule = WorkoutSchedule(config: WorkoutConfig(warmUp: 15, work: 15, rest: 15, intervals: 3))
		let times = schedule.cues.map(\.time)
		#expect(times == times.sorted())
	}

	@Test func shouldFindPhaseContainingElapsedTime() {
		let schedule = WorkoutSchedule(config: WorkoutConfig(warmUp: 60, work: 30, rest: 15, intervals: 2))
		#expect(schedule.phaseIndex(at: 0) == 0)
		#expect(schedule.phaseIndex(at: 59.9) == 0)
		#expect(schedule.phaseIndex(at: 60) == 1)
		#expect(schedule.phaseIndex(at: 100) == 2)
		#expect(schedule.phaseIndex(at: 134.9) == 3)
	}

	@Test func shouldReturnNilPhaseOnceWorkoutIsOver() {
		let schedule = WorkoutSchedule(config: WorkoutConfig(warmUp: 60, work: 30, rest: 15, intervals: 2))
		#expect(schedule.phaseIndex(at: 135) == nil)
	}
}
