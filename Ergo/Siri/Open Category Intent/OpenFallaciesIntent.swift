

import AppIntents

@AppIntent(.tool)
struct OpenFallaciesIntent: AppIntent {
	static let title: LocalizedStringResource = "Show Fallacies"

	static let description = IntentDescription(
		"Opens the list of logical fallacies in Ergo. Filters by category tags, replacing any filters already applied. Passing none removes all filters."
	)

	@Parameter(
		title: "Tags",
		description: "Category tags to filter by, such as causal reasoning. A fallacy matches if it has any of these tags."
	)
	var tags: [FallacyTag]?

	static var parameterSummary: some ParameterSummary {
		Summary("Show fallacies") {
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
			.fallacies,
			filters: (tags ?? []).map(\.libraryFilter)
		)

		return .result()
	}
}
