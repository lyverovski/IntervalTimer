import Foundation
import Observation
import os

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

/// Shows the workout on the lock screen and in the Dynamic Island.
protocol LiveActivityUpdating: AnyObject {
	/// Starts a Live Activity for a new workout.
	/// - Parameter state: The initial phase.
	func start(_ state: WorkoutActivityAttributes.ContentState)
	/// Replaces what the Live Activity shows.
	/// - Parameter state: The new phase or paused state.
	func update(_ state: WorkoutActivityAttributes.ContentState)
	/// Ends the Live Activity.
	/// - Parameters:
	///   - state: The final content to show while it's dismissed.
	///   - immediately: `true` to remove it at once (stopped), `false` to leave the result up briefly (finished).
	func end(_ state: WorkoutActivityAttributes.ContentState, immediately: Bool)
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
	private static let logger = Logger(subsystem: "com.andrelyver.IntervalTimer", category: "engine")

	private(set) var state: State = .idle
	private(set) var schedule: WorkoutSchedule?
	private(set) var elapsed: TimeInterval = 0

	@ObservationIgnored private let cuePlayer: CuePlaying
	@ObservationIgnored private let liveActivity: LiveActivityUpdating?
	@ObservationIgnored private let tickInterval: Duration?
	@ObservationIgnored private let now: () -> Date
	@ObservationIgnored private var accumulated: TimeInterval = 0
	@ObservationIgnored private var resumedAt: Date?
	@ObservationIgnored private var nextCueIndex = 0
	@ObservationIgnored private var tickTask: Task<Void, Never>?
	/// Phase last sent to the Live Activity, so it's only updated when the phase changes.
	@ObservationIgnored private var reportedPhaseIndex: Int?

	/// - Parameters:
	///   - cuePlayer: Plays the sounds.
	///   - liveActivity: Mirrors the workout on the lock screen and Dynamic Island, if available.
	///   - tickInterval: How often to refresh while running, or `nil` to drive `tick()` manually (tests).
	///   - now: Clock source.
	init(
		cuePlayer: CuePlaying,
		liveActivity: LiveActivityUpdating? = nil,
		tickInterval: Duration? = .milliseconds(100),
		now: @escaping () -> Date = Date.init
	) {
		self.cuePlayer = cuePlayer
		self.liveActivity = liveActivity
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
		Self.logger.debug("Starting workout: \(config.intervals) intervals, \(config.totalDuration)s total")
		schedule = WorkoutSchedule(config: config.clamped())
		accumulated = 0
		elapsed = 0
		nextCueIndex = 0
		resumedAt = now()
		state = .running
		cuePlayer.beginSession()
		reportedPhaseIndex = currentPhaseIndex
		if let activityState = activityState() {
			liveActivity?.start(activityState)
		}
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
		sendActivityUpdate()
	}

	/// Resumes a paused workout from where it left off.
	func resume() {
		guard state == .paused else { return }
		resumedAt = now()
		state = .running
		// An interruption (e.g. a phone call) may have stopped our audio; reactivate it.
		cuePlayer.beginSession()
		sendActivityUpdate()
		startTicking()
	}

	/// Abandons the workout and returns to idle.
	func stop() {
		// A finished workout already ended its Live Activity with the result showing.
		if state == .running || state == .paused, let activityState = activityState() {
			liveActivity?.end(activityState, immediately: true)
		}
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
			if let activityState = activityState() {
				liveActivity?.end(activityState, immediately: false)
			}
		} else if currentPhaseIndex != reportedPhaseIndex {
			reportedPhaseIndex = currentPhaseIndex
			sendActivityUpdate()
		}
	}

	/// What the Live Activity should show right now, or `nil` with no workout.
	/// Phase start/end are absolute times so the system can animate the countdown itself.
	/// - Returns: The content state.
	func activityState() -> WorkoutActivityAttributes.ContentState? {
		guard let schedule, let last = schedule.phases.last else { return nil }
		let current = now()
		if state == .finished {
			return WorkoutActivityAttributes.ContentState(
				phase: last.kind.activityPhase, intervalNumber: totalIntervals, totalIntervals: totalIntervals,
				phaseStart: current, phaseEnd: current, pausedRemaining: nil, isFinished: true)
		}
		guard let phase = currentPhase else { return nil }
		return WorkoutActivityAttributes.ContentState(
			phase: phase.kind.activityPhase,
			intervalNumber: intervalNumber,
			totalIntervals: totalIntervals,
			phaseStart: current.addingTimeInterval(Double(phase.start) - elapsed),
			phaseEnd: current.addingTimeInterval(Double(phase.end) - elapsed),
			pausedRemaining: state == .paused ? phaseRemaining : nil
		)
	}

	private func sendActivityUpdate() {
		if let activityState = activityState() {
			liveActivity?.update(activityState)
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
