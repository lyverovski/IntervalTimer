import AVFoundation
import os

/// Plays cue tones over any other audio (no ducking) and keeps the app running in the background.
///
/// iOS suspends a backgrounded app shortly after it stops producing audio, which would stall the
/// timer. While a workout is active we loop a silent file so the session stays alive; this relies on
/// the `audio` background mode in the target's Info settings.
final class CuePlayer: CuePlaying {
	/// Time allowed for the final tone to finish before the session is released.
	private static let releaseDelay: Duration = .seconds(3)

	private let settings: SettingsStore
	private let logger = Logger(subsystem: "com.andrelyver.IntervalTimer", category: "audio")
	private var players: [String: AVAudioPlayer] = [:]
	private var silencePlayer: AVAudioPlayer?
	private var releaseTask: Task<Void, Never>?
	private var interruptionTask: Task<Void, Never>?

	/// Called when a phone call, Siri or similar takes over audio.
	var onInterruption: (() -> Void)?

	/// - Parameter settings: Source of the user's tone choices.
	init(settings: SettingsStore) {
		self.settings = settings
		configureSession()
		observeInterruptions()
	}

	func play(_ kind: CueKind) {
		play(toneID: settings.tone(for: kind).id)
	}

	/// Plays a tone immediately, e.g. to preview it in Settings.
	/// - Parameter tone: The tone to play.
	func preview(_ tone: Tone) {
		play(toneID: tone.id)
	}

	func beginSession() {
		releaseTask?.cancel()
		releaseTask = nil
		do {
			try AVAudioSession.sharedInstance().setActive(true)
		} catch {
			logger.error("Failed to activate audio session: \(error.localizedDescription)")
		}
		if silencePlayer == nil {
			silencePlayer = loadPlayer(ToneCatalog.silenceFile)
			silencePlayer?.numberOfLoops = -1
		}
		if silencePlayer?.isPlaying == false {
			silencePlayer?.play()
		}
	}

	func endSession() {
		releaseTask?.cancel()
		releaseTask = Task { [weak self] in
			do {
				try await Task.sleep(for: Self.releaseDelay)
			} catch {
				return // Cancelled because a new workout began.
			}
			self?.releaseSession()
		}
	}

	private func releaseSession() {
		silencePlayer?.stop()
		do {
			// Lets other apps know they can resume if they paused for us.
			try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
		} catch {
			logger.error("Failed to deactivate audio session: \(error.localizedDescription)")
		}
	}

	private func configureSession() {
		do {
			// .playback ignores the silent switch; .mixWithOthers plays over music without interrupting it.
			try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
		} catch {
			logger.error("Failed to configure audio session: \(error.localizedDescription)")
		}
	}

	private func observeInterruptions() {
		interruptionTask = Task { [weak self] in
			for await notification in NotificationCenter.default.notifications(named: AVAudioSession.interruptionNotification) {
				guard
					let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
					AVAudioSession.InterruptionType(rawValue: raw) == .began
				else { continue }
				self?.onInterruption?()
			}
		}
	}

	private func play(toneID: String) {
		if players[toneID] == nil {
			players[toneID] = loadPlayer(toneID)
		}
		guard let player = players[toneID] else { return }
		player.currentTime = 0
		player.play()
	}

	private func loadPlayer(_ name: String) -> AVAudioPlayer? {
		guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else {
			logger.error("Missing sound file \(name, privacy: .public).wav")
			return nil
		}
		do {
			let player = try AVAudioPlayer(contentsOf: url)
			player.prepareToPlay()
			return player
		} catch {
			logger.error("Failed to load \(name, privacy: .public): \(error.localizedDescription)")
			return nil
		}
	}
}
