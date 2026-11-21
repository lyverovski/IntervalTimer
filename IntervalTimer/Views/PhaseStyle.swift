import SwiftUI

/// Display name and color for each phase, shared with the Live Activity via `ActivityPhase`.
extension PhaseKind {
	var title: String { activityPhase.title }
	var color: Color { activityPhase.color }
}
