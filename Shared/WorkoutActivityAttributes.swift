import ActivityKit
import SwiftUI

// Compiled into both the app and the widget extension, so the Live Activity
// renders with exactly the same phase names, colors and time format as the app.

/// The phase shown in the Live Activity and running screen.
nonisolated enum ActivityPhase: String, Codable, Hashable, Sendable {
	case getReady
	case warmUp
	case work
	case rest

	var title: String {
		switch self {
		case .getReady: "Get Ready"
		case .warmUp: "Warm-Up"
		case .work: "Work"
		case .rest: "Rest"
		}
	}

	var color: Color {
		switch self {
		case .getReady: .yellow
		case .warmUp: .orange
		case .work: .red
		case .rest: .teal
		}
	}
}

/// Live Activity payload. The countdown is rendered by the system from `phaseStart`/`phaseEnd`,
/// so the app only needs to send an update when the phase changes or the workout pauses.
nonisolated struct WorkoutActivityAttributes: ActivityAttributes, Sendable {
	struct ContentState: Codable, Hashable, Sendable {
		var phase: ActivityPhase
		/// Most recent work interval reached; 0 during warm-up.
		var intervalNumber: Int
		var totalIntervals: Int
		var phaseStart: Date
		var phaseEnd: Date
		/// Seconds left in the phase while paused, frozen; `nil` while running.
		var pausedRemaining: Int?
		var isFinished: Bool = false

		var isPaused: Bool { pausedRemaining != nil }

		/// "Interval 2 of 8", or "Up next: Interval 1 of 8" before the first interval.
		var intervalLabel: String {
			intervalNumber == 0
				? "Up next: Interval 1 of \(totalIntervals)"
				: "Interval \(intervalNumber) of \(totalIntervals)"
		}
	}
}

nonisolated enum TimeFormat {
	/// Formats a duration as `m:ss`, letting minutes exceed 59 (e.g. `90:15`).
	/// - Parameter seconds: Non-negative duration in seconds.
	/// - Returns: The formatted string.
	static func minutesSeconds(_ seconds: Int) -> String {
		let clamped = max(seconds, 0)
		return String(format: "%d:%02d", clamped / 60, clamped % 60)
	}
}
