import SwiftUI

/// Display name and color for each phase, shared by the running screen's label, bar and segments.
extension PhaseKind {
	var title: String {
		switch self {
		case .getReady: "Get Ready"
		case .warmUp: "Warm-Up"
		case .work: "Work"
		case .rest: "Rest"
		}
	}

	var color: Color {
		switch self {
		case .getReady: .yellow
		case .warmUp: .orange
		case .work: .red
		case .rest: .teal
		}
	}
}
