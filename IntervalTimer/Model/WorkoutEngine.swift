import Foundation
import Observation

/// Plays cue sounds and keeps the app's audio session alive for the length of a workout.
protocol CuePlaying: AnyObject {
	/// Plays the tone currently selected for a cue.
	/// - Parameter kind: Which cue to play.
	func play(_ kind: CueKind)
	/// Activates audio so cues keep playing with the screen locked.
	func beginSession()
	/// Releases audio once the workout is over.
	func endSession()
}

/// Runs a workout: tracks elapsed time, the current phase, and fires sound cues on schedule.
///
/// Elapsed time is always derived from the clock rather than counted from ticks, so a late
/// or skipped tick (e.g. while the app is backgrounded) never causes drift.
@Observable
final class WorkoutEngine {
	enum State: Equatable {
		case idle
		case running
		case paused
		case finished
	}

	/// Cues older than this when a tick finally arrives are skipped rather than played late,
	/// so returning from a long suspension doesn't produce a burst of beeps.
	static let staleCueTolerance: TimeInterval = 1.0

	private(set) var state: State = .idle
	private(set) var schedule: WorkoutSchedule?
	private(set) var elapsed: TimeInterval = 0

	@ObservationIgnored private let cuePlayer: CuePlaying
	@ObservationIgnored private let tickInterval: Duration?
	@ObservationIgnored private let now: () -> Date
	@ObservationIgnored private var accumulated: TimeInterval = 0
	@ObservationIgnored private var resumedAt: Date?
	@ObservationIgnored private var nextCueIndex = 0
	@ObservationIgnored private var tickTask: Task<Void, Never>?

	/// - Parameters:
	///   - cuePlayer: Plays the sounds.
	///   - tickInterval: How often to refresh while running, or `nil` to drive `tick()` manually (tests).
	///   - now: Clock source.
	init(cuePlayer: CuePlaying, tickInterval: Duration? = .milliseconds(100), now: @escaping () -> Date = Date.init) {
		self.cuePlayer = cuePlayer
		self.tickInterval = tickInterval
		self.now = now
	}

	var currentPhaseIndex: Int? {
		guard state == .running || state == .paused else { return nil }
		return schedule?.phaseIndex(at: elapsed)
	}

	var currentPhase: Phase? {
		currentPhaseIndex.flatMap { schedule?.phases[$0] }
	}

	/// Whole seconds left in the current phase, rounded up so the display never shows 0 mid-phase.
	var phaseRemaining: Int {
		guard let phase = currentPhase else { return 0 }
		return Int((Double(phase.end) - elapsed).rounded(.up))
	}

	/// Fraction of the current phase completed, from 0 to 1.
	var phaseProgress: Double {
		guard let phase = currentPhase, phase.duration > 0 else { return 0 }
		return (elapsed - Double(phase.start)) / Double(phase.duration)
	}

	/// The most recent work interval reached, so rest shows the interval just completed. 0 before the first.
	var intervalNumber: Int {
		guard let schedule, let index = currentPhaseIndex else { return 0 }
		for phase in schedule.phases[...index].reversed() {
			switch phase.kind {
			case .work(let number), .rest(let number):
				return number
			case .warmUp, .getReady:
				continue
			}
		}
		return 0
	}

	var totalIntervals: Int {
		schedule?.phases.filter { if case .work = $0.kind { true } else { false } }.count ?? 0
	}

	/// Starts a new workout from the beginning.
	/// - Parameter config: The workout settings.
	func start(config: WorkoutConfig) {
		schedule = WorkoutSchedule(config: config.clamped())
		accumulated = 0
		elapsed = 0
		nextCueIndex = 0
		resumedAt = now()
		state = .running
		cuePlayer.beginSession()
		startTicking()
	}

	/// Pauses a running workout.
	func pause() {
		guard state == .running, let resumedAt else { return }
		accumulated += now().timeIntervalSince(resumedAt)
		self.resumedAt = nil
		elapsed = accumulated
		state = .paused
		stopTicking()
	}

	/// Resumes a paused workout from where it left off.
	func resume() {
		guard state == .paused else { return }
		resumedAt = now()
		state = .running
		startTicking()
	}

	/// Abandons the workout and returns to idle.
	func stop() {
		stopTicking()
		state = .idle
		schedule = nil
		elapsed = 0
		resumedAt = nil
		cuePlayer.endSession()
	}

	/// Called when another app or a phone call takes over audio.
	func handleInterruption() {
		pause()
	}

	/// Recomputes elapsed time, fires any cues that are due and detects the end of the workout.
	func tick() {
		guard state == .running, let schedule, let resumedAt else { return }
		elapsed = accumulated + now().timeIntervalSince(resumedAt)

		while nextCueIndex < schedule.cues.count, Double(schedule.cues[nextCueIndex].time) <= elapsed {
			let cue = schedule.cues[nextCueIndex]
			nextCueIndex += 1
			// The finish sound always plays: it's the user's signal that the workout is done.
			if cue.kind == .finish || elapsed - Double(cue.time) <= Self.staleCueTolerance {
				cuePlayer.play(cue.kind)
			}
		}

		if elapsed >= Double(schedule.duration) {
			elapsed = Double(schedule.duration)
			state = .finished
			stopTicking()
			cuePlayer.endSession()
		}
	}

	private func startTicking() {
		guard let tickInterval else { return }
		tickTask?.cancel()
		tickTask = Task { [weak self] in
			while !Task.isCancelled {
				self?.tick()
				try? await Task.sleep(for: tickInterval)
			}
		}
	}

	private func stopTicking() {
		tickTask?.cancel()
		tickTask = nil
	}
}
