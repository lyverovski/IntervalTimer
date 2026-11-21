import Foundation

nonisolated enum PhaseKind: Equatable, Sendable {
	case getReady
	case warmUp
	case work(number: Int)
	case rest(number: Int)
}

extension PhaseKind {
	/// The phase as shown in the Live Activity (interval numbers dropped).
	nonisolated var activityPhase: ActivityPhase {
		switch self {
		case .getReady: .getReady
		case .warmUp: .warmUp
		case .work: .work
		case .rest: .rest
		}
	}
}

nonisolated struct Phase: Equatable, Sendable {
	let kind: PhaseKind
	/// Offset from workout start, in seconds.
	let start: Int
	let duration: Int

	var end: Int { start + duration }
}

nonisolated enum CueKind: String, CaseIterable, Codable, Sendable {
	case countdown
	case intervalStart
	case intervalEnd
	case finish
}

nonisolated struct Cue: Equatable, Sendable {
	/// Offset from workout start, in seconds.
	let time: Int
	let kind: CueKind
}

/// The full timeline for a workout: every phase and every sound cue, with times relative to the start.
/// Built once up front so the engine only has to look up where the elapsed time falls.
nonisolated struct WorkoutSchedule: Sendable {
	static let getReadyDuration = 15
	static let countdownSeconds = 3

	let phases: [Phase]
	let cues: [Cue]

	var duration: Int { phases.last?.end ?? 0 }

	/// Builds the timeline for a config.
	/// - Parameter config: The workout settings.
	init(config: WorkoutConfig) {
		var phases: [Phase] = []
		var cursor = 0

		func append(_ kind: PhaseKind, _ duration: Int) {
			phases.append(Phase(kind: kind, start: cursor, duration: duration))
			cursor += duration
		}

		if config.warmUp > 0 {
			append(.warmUp, config.warmUp)
		} else {
			append(.getReady, Self.getReadyDuration)
		}
		for number in 1...config.intervals {
			append(.work(number: number), config.work)
			if number < config.intervals {
				append(.rest(number: number), config.rest)
			}
		}

		var cues: [Cue] = []
		for phase in phases {
			guard case .work(let number) = phase.kind else { continue }
			for offset in stride(from: Self.countdownSeconds, through: 1, by: -1) {
				cues.append(Cue(time: phase.start - offset, kind: .countdown))
			}
			cues.append(Cue(time: phase.start, kind: .intervalStart))
			cues.append(Cue(time: phase.end, kind: number == config.intervals ? .finish : .intervalEnd))
		}

		self.phases = phases
		self.cues = cues
	}

	/// Finds the phase in progress at a point in the workout.
	/// - Parameter elapsed: Seconds since the workout started.
	/// - Returns: Index into `phases`, or `nil` once the workout has ended.
	func phaseIndex(at elapsed: TimeInterval) -> Int? {
		phases.firstIndex { elapsed >= Double($0.start) && elapsed < Double($0.end) }
	}
}
