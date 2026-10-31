import SwiftUI

/// Root view: the setup screen, with the running workout presented over it full-screen.
struct ContentView: View {
	let settings: SettingsStore
	let engine: WorkoutEngine
	let cuePlayer: CuePlayer
	@State private var showingSettings = false

	var body: some View {
		NavigationStack {
			SetupView(
				settings: settings,
				onStart: { engine.start(config: settings.config) },
				onOpenSettings: { showingSettings = true }
			)
		}
		.sheet(isPresented: $showingSettings) {
			SettingsView(settings: settings, cuePlayer: cuePlayer)
		}
		.fullScreenCover(isPresented: Binding(
			get: { engine.state != .idle },
			set: { if !$0 { engine.stop() } }
		)) {
			RunningView(engine: engine)
		}
	}
}

#Preview {
	let settings = SettingsStore()
	let player = CuePlayer(settings: settings)
	ContentView(settings: settings, engine: WorkoutEngine(cuePlayer: player), cuePlayer: player)
}
