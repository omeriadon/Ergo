

import AppIntents

@AppIntent(.tool)
struct OpenConceptsIntent: AppIntent {
	static let title: LocalizedStringResource = "Show Concepts"

	static let description = IntentDescription(
		"Opens the list of philosophical concepts in Ergo. Filters by category tags, replacing any filters already applied. Passing none removes all filters."
	)

	@Parameter(
		title: "Tags",
		description: "Category tags to filter by, such as ethics and value or thought experiments. A concept matches if it has any of these tags."
	)
	var tags: [ConceptTag]?

	static var parameterSummary: some ParameterSummary {
		Summary("Show concepts") {
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
			.concepts,
			filters: (tags ?? []).map(\.libraryFilter)
		)

		return .result()
	}
}
