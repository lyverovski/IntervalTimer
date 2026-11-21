import ActivityKit
import Foundation
import os

/// Drives the workout's Live Activity (lock screen + Dynamic Island) through ActivityKit.
/// The app updates it directly while running; no push notifications are involved.
final class LiveActivityController: LiveActivityUpdating {
	/// How long the "Workout Complete" result stays on the lock screen.
	private static let finishedLinger: TimeInterval = 60

	private let logger = Logger(subsystem: "com.andrelyver.IntervalTimer", category: "liveActivity")
	private var activity: Activity<WorkoutActivityAttributes>?

	init() {
		// A crash or force-quit mid-workout can leave an orphaned activity behind.
		Task {
			for orphan in Activity<WorkoutActivityAttributes>.activities {
				await orphan.end(nil, dismissalPolicy: .immediate)
			}
		}
	}

	func start(_ state: WorkoutActivityAttributes.ContentState) {
		guard ActivityAuthorizationInfo().areActivitiesEnabled else {
			logger.info("Live Activities are disabled in Settings")
			return
		}
		let previous = activity
		Task { await previous?.end(nil, dismissalPolicy: .immediate) }
		do {
			activity = try Activity.request(
				attributes: WorkoutActivityAttributes(),
				content: ActivityContent(state: state, staleDate: nil)
			)
		} catch {
			logger.error("Failed to start Live Activity: \(error.localizedDescription)")
			activity = nil
		}
	}

	func update(_ state: WorkoutActivityAttributes.ContentState) {
		guard let activity else { return }
		Task {
			await activity.update(ActivityContent(state: state, staleDate: nil))
		}
	}

	func end(_ state: WorkoutActivityAttributes.ContentState, immediately: Bool) {
		guard let activity else { return }
		self.activity = nil
		let policy: ActivityUIDismissalPolicy = immediately
			? .immediate
			: .after(Date().addingTimeInterval(Self.finishedLinger))
		Task {
			await activity.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: policy)
		}
	}
}
