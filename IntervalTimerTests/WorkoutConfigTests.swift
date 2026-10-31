import Foundation
import Testing
@testable import IntervalTimer

@MainActor
struct WorkoutConfigTests {

	@Test func shouldComputeTotalWithWarmUpWorkAndRestBetweenIntervals() {
		let config = WorkoutConfig(warmUp: 120, work: 60, rest: 30, intervals: 5)
		// 120 + 5×60 + 4×30
		#expect(config.totalDuration == 540)
	}

	@Test func shouldOmitRestWhenThereIsOnlyOneInterval() {
		let config = WorkoutConfig(warmUp: 0, work: 45, rest: 30, intervals: 1)
		#expect(config.totalDuration == 45)
	}

	@Test func shouldNotCountGetReadyLeadInTowardTotalWhenWarmUpIsZero() {
		let config = WorkoutConfig(warmUp: 0, work: 60, rest: 15, intervals: 2)
		#expect(config.totalDuration == 135)
	}

	@Test func shouldClampValuesBelowRangeToMinimum() {
		let config = WorkoutConfig(warmUp: -30, work: 5, rest: 0, intervals: 0).clamped()
		#expect(config == WorkoutConfig(warmUp: 0, work: 15, rest: 15, intervals: 1))
	}

	@Test func shouldClampValuesAboveRangeToMaximum() {
		let config = WorkoutConfig(warmUp: 9999, work: 9999, rest: 9999, intervals: 99).clamped()
		#expect(config == WorkoutConfig(warmUp: 600, work: 600, rest: 300, intervals: 30))
	}

	@Test func shouldSnapDurationsToNearestFifteenSecondStep() {
		let config = WorkoutConfig(warmUp: 22, work: 68, rest: 37, intervals: 3).clamped()
		#expect(config == WorkoutConfig(warmUp: 15, work: 75, rest: 30, intervals: 3))
	}

	@Test func shouldRoundTripThroughJSON() throws {
		let config = WorkoutConfig(warmUp: 300, work: 240, rest: 60, intervals: 4)
		let data = try JSONEncoder().encode(config)
		#expect(try JSONDecoder().decode(WorkoutConfig.self, from: data) == config)
	}

	@Test(arguments: [
		(0, "0:00"),
		(9, "0:09"),
		(75, "1:15"),
		(600, "10:00"),
		(5415, "90:15"),
	])
	func shouldFormatSecondsAsMinutesAndSeconds(seconds: Int, expected: String) {
		#expect(TimeFormat.minutesSeconds(seconds) == expected)
	}
}
