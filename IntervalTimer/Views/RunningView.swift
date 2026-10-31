import SwiftUI

/// Full-screen view while a workout is running, paused or just finished.
struct RunningView: View {
	let engine: WorkoutEngine
	@State private var confirmingStop = false

	var body: some View {
		VStack(spacing: 32) {
			if engine.state == .finished {
				finished
			} else if let phase = engine.currentPhase {
				header(for: phase)
				Text(TimeFormat.minutesSeconds(engine.phaseRemaining))
					.font(.system(size: 96, weight: .bold, design: .rounded))
					.monospacedDigit()
					.contentTransition(.numericText(countsDown: true))
				PhaseBar(progress: engine.phaseProgress, color: phase.kind.color)
				if let schedule = engine.schedule {
					WorkoutSegments(schedule: schedule, elapsed: engine.elapsed)
				}
				Spacer()
				controls
			}
		}
		.padding(24)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background((engine.currentPhase?.kind.color ?? .green).opacity(0.12).ignoresSafeArea())
		.animation(.easeInOut(duration: 0.3), value: engine.currentPhaseIndex)
		.confirmationDialog("End this workout?", isPresented: $confirmingStop, titleVisibility: .visible) {
			Button("End Workout", role: .destructive) { engine.stop() }
		}
	}

	private func header(for phase: Phase) -> some View {
		VStack(spacing: 8) {
			Text(phase.kind.title.uppercased())
				.font(.title.weight(.heavy))
				.foregroundStyle(phase.kind.color)
			Text(intervalLabel(for: phase))
				.font(.title3)
				.foregroundStyle(.secondary)
		}
		.padding(.top, 40)
	}

	private func intervalLabel(for phase: Phase) -> String {
		switch phase.kind {
		case .getReady, .warmUp:
			"Up next: Interval 1 of \(engine.totalIntervals)"
		case .work, .rest:
			"Interval \(engine.intervalNumber) of \(engine.totalIntervals)"
		}
	}

	private var controls: some View {
		HStack(spacing: 16) {
			Button(role: .destructive) {
				confirmingStop = true
			} label: {
				Label("Stop", systemImage: "stop.fill")
					.frame(maxWidth: .infinity)
			}
			.buttonStyle(.bordered)

			Button {
				engine.state == .paused ? engine.resume() : engine.pause()
			} label: {
				Label(engine.state == .paused ? "Resume" : "Pause",
					systemImage: engine.state == .paused ? "play.fill" : "pause.fill")
					.frame(maxWidth: .infinity)
			}
			.buttonStyle(.borderedProminent)
		}
		.font(.title3.weight(.semibold))
		.controlSize(.large)
	}

	private var finished: some View {
		VStack(spacing: 24) {
			Spacer()
			Image(systemName: "checkmark.circle.fill")
				.font(.system(size: 96))
				.foregroundStyle(.green)
			Text("Workout Complete")
				.font(.largeTitle.weight(.bold))
			if let schedule = engine.schedule {
				Text("\(engine.totalIntervals) intervals · \(TimeFormat.minutesSeconds(schedule.duration))")
					.font(.title3)
					.foregroundStyle(.secondary)
			}
			Spacer()
			Button {
				engine.stop()
			} label: {
				Text("Done")
					.font(.title3.weight(.semibold))
					.frame(maxWidth: .infinity)
			}
			.buttonStyle(.borderedProminent)
			.controlSize(.large)
		}
	}
}

/// Fills left to right over the current phase, shaded with a gradient in the phase's color.
private struct PhaseBar: View {
	let progress: Double
	let color: Color

	var body: some View {
		GeometryReader { geometry in
			ZStack(alignment: .leading) {
				Capsule()
					.fill(color.opacity(0.2))
				Capsule()
					.fill(LinearGradient(colors: [color.opacity(0.55), color], startPoint: .leading, endPoint: .trailing))
					.frame(width: geometry.size.width * min(max(progress, 0), 1))
			}
		}
		.frame(height: 28)
		.animation(.linear(duration: 0.1), value: progress)
	}
}

/// One segment per phase, sized by duration, showing overall progress through the workout.
private struct WorkoutSegments: View {
	let schedule: WorkoutSchedule
	let elapsed: TimeInterval

	var body: some View {
		GeometryReader { geometry in
			let spacing: CGFloat = 2
			let available = geometry.size.width - spacing * CGFloat(schedule.phases.count - 1)
			HStack(spacing: spacing) {
				ForEach(Array(schedule.phases.enumerated()), id: \.offset) { _, phase in
					RoundedRectangle(cornerRadius: 2)
						.fill(phase.kind.color.opacity(Double(phase.end) <= elapsed ? 1 : 0.25))
						.frame(width: max(available * CGFloat(phase.duration) / CGFloat(schedule.duration), 1))
				}
			}
		}
		.frame(height: 8)
	}
}
