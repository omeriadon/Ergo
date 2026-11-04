

import AppIntents

@AppIntent(.tool)
struct OpenParadoxesIntent: AppIntent {
	static let title: LocalizedStringResource = "Show Paradoxes"

	static let description = IntentDescription(
		"Opens the list of philosophical paradoxes in Ergo. Filters by category tags, replacing any filters already applied. Passing none removes all filters."
	)

	@Parameter(
		title: "Tags",
		description: "Category tags to filter by, such as logic and language or metaphysics. A paradox matches if it has any of these tags."
	)
	var tags: [ParadoxTag]?

	static var parameterSummary: some ParameterSummary {
		Summary("Show paradoxes") {
			\.$tags
		}
	}

	@Dependency
	private var navigation: NavigationManager

	static var supportedModes: IntentModes = [
		.foreground(.immediate),
	]

	@MainActor
	func perform() async throws -> some IntentResult {
		navigation.showLibraryList(
			.paradoxes,
			filters: (tags ?? []).map(\.libraryFilter)
		)

		return .result()
	}
}
