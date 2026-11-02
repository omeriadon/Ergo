import Foundation

nonisolated enum ArgumentTag: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
	case ethics
	case epistemology
	case metaphysics
	case mind
	case religion
	case politicalPhilosophy = "political-philosophy"

	var title: String {
		switch self {
			case .politicalPhilosophy:
				"Political Philosophy"
			default:
				rawValue.capitalized
		}
	}

	var id: Self {
		self
	}
}
