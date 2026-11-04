

import AppIntents

@AppIntent(.tool)
struct OpenBiasesIntent: AppIntent {
	static let title: LocalizedStringResource = "Show Biases"

	static let description = IntentDescription(
		"Opens the list of cognitive biases in Ergo. Filters by category tags, replacing any filters already applied. Passing none removes all filters."
	)

	@Parameter(
		title: "Tags",
		description: "Category tags to filter by, such as memory or decision making. A bias matches if it has any of these tags."
	)
	var tags: [BiasTag]?

	static var parameterSummary: some ParameterSummary {
		Summary("Show biases") {
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
			.biases,
			filters: (tags ?? []).map(\.libraryFilter)
		)

		return .result()
	}
}
