import Foundation
import Observation

/// Persists the last-used workout config and the tone chosen for each cue.
/// Everything read back from storage is validated, falling back to defaults.
@Observable
final class SettingsStore {
	static let configKey = "workoutConfig"

	/// - Parameter kind: The cue.
	/// - Returns: The UserDefaults key holding that cue's tone ID.
	static func toneKey(for kind: CueKind) -> String {
		"tone.\(kind.rawValue)"
	}

	var config: WorkoutConfig {
		didSet { saveConfig() }
	}

	private var toneIDs: [CueKind: String]
	@ObservationIgnored private let defaults: UserDefaults

	/// - Parameter defaults: Backing store; inject a suite in tests.
	init(defaults: UserDefaults = .standard) {
		self.defaults = defaults
		config = Self.loadConfig(from: defaults)
		toneIDs = Dictionary(uniqueKeysWithValues: CueKind.allCases.compactMap { kind in
			defaults.string(forKey: Self.toneKey(for: kind)).map { (kind, $0) }
		})
	}

	/// The selected tone for a cue, or the default if none is saved or the saved one no longer exists.
	/// - Parameter kind: The cue.
	/// - Returns: The tone to play.
	func tone(for kind: CueKind) -> Tone {
		let options = ToneCatalog.tones(for: kind)
		return options.first { $0.id == toneIDs[kind] } ?? ToneCatalog.defaultTone(for: kind)
	}

	/// Saves the tone for a cue. Ignored if the tone isn't offered for that cue.
	/// - Parameters:
	///   - tone: The tone to use.
	///   - kind: The cue.
	func setTone(_ tone: Tone, for kind: CueKind) {
		guard ToneCatalog.tones(for: kind).contains(tone) else { return }
		toneIDs[kind] = tone.id
		defaults.set(tone.id, forKey: Self.toneKey(for: kind))
	}

	private static func loadConfig(from defaults: UserDefaults) -> WorkoutConfig {
		guard let data = defaults.data(forKey: configKey) else { return .default }
		do {
			return try JSONDecoder().decode(WorkoutConfig.self, from: data).clamped()
		} catch {
			// Corrupt or from an incompatible version: start fresh rather than crash.
			return .default
		}
	}

	private func saveConfig() {
		do {
			defaults.set(try JSONEncoder().encode(config), forKey: Self.configKey)
		} catch {
			// Encoding a plain struct of Ints can't realistically fail; losing one save is harmless.
			assertionFailure("Failed to encode config: \(error)")
		}
	}
}
