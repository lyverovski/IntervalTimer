import SwiftUI

/// Lets the user pick and preview the tone for each cue.
struct SettingsView: View {
	let settings: SettingsStore
	let cuePlayer: CuePlayer
	@Environment(\.dismiss) private var dismiss

	var body: some View {
		NavigationStack {
			Form {
				ForEach(CueKind.allCases, id: \.self) { kind in
					Section(kind.settingsTitle) {
						ForEach(ToneCatalog.tones(for: kind)) { tone in
							Button {
								settings.setTone(tone, for: kind)
								cuePlayer.preview(tone)
							} label: {
								HStack {
									Text(tone.name)
										.foregroundStyle(.primary)
									Spacer()
									if settings.tone(for: kind) == tone {
										Image(systemName: "checkmark")
											.foregroundStyle(.tint)
									}
								}
							}
						}
					}
				}
			}
			.navigationTitle("Sounds")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .confirmationAction) {
					Button("Done") { dismiss() }
				}
			}
		}
	}
}

private extension CueKind {
	var settingsTitle: String {
		switch self {
		case .countdown: "Countdown (3, 2, 1)"
		case .intervalStart: "Interval Start"
		case .intervalEnd: "Interval End"
		case .finish: "Workout Complete"
		}
	}
}
