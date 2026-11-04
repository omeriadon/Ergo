

import AppIntents

@AppIntent(.tool)
struct OpenPhilosophersIntent: AppIntent {
	static let title: LocalizedStringResource = "Show Philosophers"

	static let description = IntentDescription(
		"Opens the list of philosophers in Ergo."
	)

	@Dependency
	private var navigation: NavigationManager

	static var supportedModes: IntentModes = [
		.foreground(.immediate),
	]

	@MainActor
	func perform() async throws -> some IntentResult {
		navigation.showLibraryList(.philosophers)

		return .result()
	}
}
