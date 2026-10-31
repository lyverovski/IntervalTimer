import SwiftUI

/// The main screen: sliders for each setting, the computed total, and Start.
struct SetupView: View {
	@Bindable var settings: SettingsStore
	let onStart: () -> Void
	let onOpenSettings: () -> Void

	var body: some View {
		Form {
			Section {
				DurationSlider(title: "Warm-Up", seconds: $settings.config.warmUp, range: WorkoutConfig.warmUpRange,
					zeroLabel: "Off")
				DurationSlider(title: "Interval", seconds: $settings.config.work, range: WorkoutConfig.workRange)
				DurationSlider(title: "Rest", seconds: $settings.config.rest, range: WorkoutConfig.restRange)
				IntervalCountSlider(count: $settings.config.intervals)
			}

			Section {
				VStack(spacing: 4) {
					Text("Total Workout Time")
						.font(.subheadline)
						.foregroundStyle(.secondary)
					Text(TimeFormat.minutesSeconds(settings.config.totalDuration))
						.font(.system(size: 48, weight: .semibold, design: .rounded))
						.monospacedDigit()
						.contentTransition(.numericText())
				}
				.frame(maxWidth: .infinity)
				.padding(.vertical, 8)
			}

			Section {
				Button(action: onStart) {
					Text("Start")
						.font(.title2.weight(.semibold))
						.frame(maxWidth: .infinity)
						.padding(.vertical, 8)
				}
				.buttonStyle(.borderedProminent)
				.listRowInsets(EdgeInsets())
			}
		}
		.navigationTitle("Interval Timer")
		.toolbar {
			ToolbarItem(placement: .topBarTrailing) {
				Button(action: onOpenSettings) {
					Image(systemName: "gearshape")
				}
			}
		}
	}
}

/// A slider in 15-second steps showing its value as m:ss.
private struct DurationSlider: View {
	let title: String
	@Binding var seconds: Int
	let range: ClosedRange<Int>
	var zeroLabel: String?

	var body: some View {
		VStack(alignment: .leading) {
			HStack {
				Text(title)
				Spacer()
				Text(seconds == 0 ? (zeroLabel ?? "0:00") : TimeFormat.minutesSeconds(seconds))
					.monospacedDigit()
					.foregroundStyle(.secondary)
			}
			Slider(
				value: Binding(get: { Double(seconds) }, set: { seconds = Int($0) }),
				in: Double(range.lowerBound)...Double(range.upperBound),
				step: Double(WorkoutConfig.durationStep)
			)
		}
	}
}

private struct IntervalCountSlider: View {
	@Binding var count: Int

	var body: some View {
		VStack(alignment: .leading) {
			HStack {
				Text("Intervals")
				Spacer()
				Text("\(count)")
					.monospacedDigit()
					.foregroundStyle(.secondary)
			}
			Slider(
				value: Binding(get: { Double(count) }, set: { count = Int($0) }),
				in: Double(WorkoutConfig.intervalsRange.lowerBound)...Double(WorkoutConfig.intervalsRange.upperBound),
				step: 1
			)
		}
	}
}
