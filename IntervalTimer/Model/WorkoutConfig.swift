import Foundation

/// The user's workout settings. All durations are in whole seconds.
nonisolated struct WorkoutConfig: Codable, Equatable, Sendable {
	var warmUp: Int
	var work: Int
	var rest: Int
	var intervals: Int

	static let durationStep = 15
	static let warmUpRange = 0...600
	static let workRange = 15...600
	static let restRange = 15...300
	static let intervalsRange = 1...30

	static let `default` = WorkoutConfig(warmUp: 300, work: 60, rest: 60, intervals: 8)

	/// Total workout time shown to the user: warm-up plus every work interval and the rests between them.
	/// The 15-second get-ready lead-in used when warm-up is zero is deliberately excluded.
	/// - Returns: Duration in seconds.
	var totalDuration: Int {
		warmUp + intervals * work + (intervals - 1) * rest
	}

	/// Returns a copy with each value snapped to the slider step and clamped to its allowed range.
	/// Use on any config loaded from storage so a corrupted or outdated value can't break the schedule.
	/// - Returns: A valid config.
	func clamped() -> WorkoutConfig {
		WorkoutConfig(
			warmUp: Self.snap(warmUp, to: Self.warmUpRange),
			work: Self.snap(work, to: Self.workRange),
			rest: Self.snap(rest, to: Self.restRange),
			intervals: min(max(intervals, Self.intervalsRange.lowerBound), Self.intervalsRange.upperBound)
		)
	}

	private static func snap(_ value: Int, to range: ClosedRange<Int>) -> Int {
		let stepped = Int((Double(value) / Double(durationStep)).rounded()) * durationStep
		return min(max(stepped, range.lowerBound), range.upperBound)
	}
}
