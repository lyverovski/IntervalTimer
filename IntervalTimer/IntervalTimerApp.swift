import SwiftUI

@main
struct IntervalTimerApp: App {
	@State private var settings: SettingsStore
	@State private var engine: WorkoutEngine
	private let cuePlayer: CuePlayer

	init() {
		let settings = SettingsStore()
		let cuePlayer = CuePlayer(settings: settings)
		let engine = WorkoutEngine(cuePlayer: cuePlayer, liveActivity: LiveActivityController())
		cuePlayer.onInterruption = { [weak engine] in engine?.handleInterruption() }
		_settings = State(initialValue: settings)
		_engine = State(initialValue: engine)
		self.cuePlayer = cuePlayer
	}

	var body: some Scene {
		WindowGroup {
			ContentView(settings: settings, engine: engine, cuePlayer: cuePlayer)
		}
	}
}
