

import AppIntents

@AppIntent(.tool)
struct OpenArgumentsIntent: AppIntent {
	static let title: LocalizedStringResource = "Show Arguments"

	static let description = IntentDescription(
		"Opens the list of philosophical arguments in Ergo. Filters by category tags, replacing any filters already applied. Passing none removes all filters."
	)

	@Parameter(
		title: "Tags",
		description: "Category tags to filter by, such as ethics or epistemology. An argument matches if it has any of these tags."
	)
	var tags: [ArgumentTag]?

	static var parameterSummary: some ParameterSummary {
		Summary("Show arguments") {
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
			.arguments,
			filters: (tags ?? []).map(\.libraryFilter)
		)

		return .result()
	}
}
