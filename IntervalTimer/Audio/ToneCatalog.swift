import Foundation

/// A bundled sound. `id` is the WAV file's name without extension.
nonisolated struct Tone: Identifiable, Hashable, Sendable {
	let id: String
	let name: String
}

/// The bundled tones the user can choose from for each cue.
/// iOS doesn't expose system ringtones to apps, so these ship with the app (see `scripts/generate_tones.py`).
nonisolated enum ToneCatalog {
	static let silenceFile = "silence"

	private static let beeps = [
		Tone(id: "beep-soft", name: "Soft Beep"),
		Tone(id: "beep-tick", name: "Tick"),
		Tone(id: "beep-low", name: "Low Beep"),
	]

	private static let bings = [
		Tone(id: "bing-bell", name: "Bell"),
		Tone(id: "bing-glass", name: "Glass"),
		Tone(id: "bing-chime", name: "Chime"),
		Tone(id: "bing-low", name: "Low Bell"),
	]

	private static let tadas = [
		Tone(id: "tada-fanfare", name: "Fanfare"),
		Tone(id: "tada-sparkle", name: "Sparkle"),
	]

	/// Tones offered for a cue, in display order.
	/// - Parameter kind: The cue.
	/// - Returns: The tones; the first is the default.
	static func tones(for kind: CueKind) -> [Tone] {
		switch kind {
		case .countdown: beeps
		case .intervalStart, .intervalEnd: bings
		case .finish: tadas
		}
	}

	/// The tone used for a cue until the user picks another.
	/// - Parameter kind: The cue.
	/// - Returns: The default tone.
	static func defaultTone(for kind: CueKind) -> Tone {
		tones(for: kind)[0]
	}
}
