import ActivityKit
import SwiftUI
import WidgetKit

/// The workout's Live Activity: a lock-screen banner plus the Dynamic Island presentations.
struct WorkoutLiveActivity: Widget {
	var body: some WidgetConfiguration {
		ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
			LockScreenView(state: context.state)
				.activityBackgroundTint(Color.black.opacity(0.75))
				.activitySystemActionForegroundColor(.white)
		} dynamicIsland: { context in
			let state = context.state
			return DynamicIsland {
				DynamicIslandExpandedRegion(.leading) {
					PhaseLabel(state: state)
						.padding(.leading, 4)
				}
				DynamicIslandExpandedRegion(.trailing) {
					Countdown(state: state)
						.font(.title2.weight(.bold))
						.frame(maxWidth: 90, alignment: .trailing)
						.padding(.trailing, 4)
				}
				DynamicIslandExpandedRegion(.bottom) {
					VStack(alignment: .leading, spacing: 6) {
						PhaseProgress(state: state)
						Text(state.isFinished ? "Workout Complete" : state.intervalLabel)
							.font(.caption)
							.foregroundStyle(.secondary)
					}
					.padding(.horizontal, 4)
				}
			} compactLeading: {
				Image(systemName: state.isFinished ? "checkmark.circle.fill" : state.isPaused ? "pause.circle.fill" : "circle.fill")
					.foregroundStyle(state.isFinished ? .green : state.phase.color)
			} compactTrailing: {
				Countdown(state: state)
					.font(.body.weight(.semibold))
					// Timer text otherwise reserves room for hours and pushes against the camera.
					.frame(maxWidth: 46, alignment: .trailing)
			} minimal: {
				PhaseProgress(state: state, style: .ring)
			}
			.keylineTint(state.phase.color)
		}
	}
}

private struct LockScreenView: View {
	let state: WorkoutActivityAttributes.ContentState

	var body: some View {
		VStack(alignment: .leading, spacing: 10) {
			HStack(alignment: .firstTextBaseline) {
				VStack(alignment: .leading, spacing: 2) {
					PhaseLabel(state: state)
					Text(state.isFinished ? "Workout Complete" : state.intervalLabel)
						.font(.subheadline)
						.foregroundStyle(.white.opacity(0.7))
				}
				Spacer()
				Countdown(state: state)
					.font(.system(size: 40, weight: .bold, design: .rounded))
					.frame(maxWidth: 140, alignment: .trailing)
			}
			PhaseProgress(state: state)
		}
		.foregroundStyle(.white)
		.padding(16)
	}
}

private struct PhaseLabel: View {
	let state: WorkoutActivityAttributes.ContentState

	var body: some View {
		HStack(spacing: 6) {
			if state.isPaused {
				Image(systemName: "pause.fill")
			}
			Text(state.isFinished ? "DONE" : state.phase.title.uppercased())
		}
		.font(.headline.weight(.heavy))
		.foregroundStyle(state.isFinished ? .green : state.phase.color)
	}
}

/// Remaining time in the phase. Runs on its own from the phase end date; frozen while paused.
private struct Countdown: View {
	let state: WorkoutActivityAttributes.ContentState

	var body: some View {
		Group {
			if state.isFinished {
				Image(systemName: "checkmark")
			} else if let remaining = state.pausedRemaining {
				Text(TimeFormat.minutesSeconds(remaining))
			} else {
				Text(timerInterval: state.phaseStart...max(state.phaseStart, state.phaseEnd), countsDown: true)
			}
		}
		.monospacedDigit()
		.multilineTextAlignment(.trailing)
	}
}

/// Progress through the current phase, as a bar or (for the minimal island) a ring.
private struct PhaseProgress: View {
	enum Style {
		case bar
		case ring
	}

	let state: WorkoutActivityAttributes.ContentState
	var style: Style = .bar

	private var frozenFraction: Double {
		let total = state.phaseEnd.timeIntervalSince(state.phaseStart)
		guard total > 0, let remaining = state.pausedRemaining else { return 1 }
		return min(max(1 - Double(remaining) / total, 0), 1)
	}

	var body: some View {
		let tint = state.isFinished ? Color.green : state.phase.color
		Group {
			if state.isFinished || state.isPaused {
				ProgressView(value: state.isFinished ? 1 : frozenFraction)
			} else {
				ProgressView(timerInterval: state.phaseStart...max(state.phaseStart, state.phaseEnd), countsDown: false) {
					EmptyView()
				} currentValueLabel: {
					EmptyView()
				}
			}
		}
		.modifier(ProgressStyleModifier(style: style))
		.tint(tint)
	}
}

private struct ProgressStyleModifier: ViewModifier {
	let style: PhaseProgress.Style

	func body(content: Content) -> some View {
		switch style {
		case .bar: content.progressViewStyle(.linear)
		case .ring: content.progressViewStyle(.circular)
		}
	}
}

#Preview("Lock screen", as: .content, using: WorkoutActivityAttributes()) {
	WorkoutLiveActivity()
} contentStates: {
	WorkoutActivityAttributes.ContentState(phase: .work, intervalNumber: 3, totalIntervals: 8,
		phaseStart: .now, phaseEnd: .now.addingTimeInterval(60), pausedRemaining: nil)
	WorkoutActivityAttributes.ContentState(phase: .rest, intervalNumber: 3, totalIntervals: 8,
		phaseStart: .now, phaseEnd: .now.addingTimeInterval(30), pausedRemaining: 18)
}
