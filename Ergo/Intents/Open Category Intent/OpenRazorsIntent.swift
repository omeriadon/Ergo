

import AppIntents

@AppIntent(.tool)
struct OpenRazorsIntent: AppIntent {
	static let title: LocalizedStringResource = "Show Razors"

	static let description = IntentDescription(
		"Opens the list of philosophical razors in Ergo, such as Occam's razor. Filters by category tags, replacing any filters already applied. Passing none removes all filters."
	)

	@Parameter(
		title: "Tags",
		description: "Category tags to filter by, such as evidence or parsimony. A razor matches if it has any of these tags."
	)
	var tags: [RazorTag]?

	static var parameterSummary: some ParameterSummary {
		Summary("Show razors") {
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
			.razors,
			filters: (tags ?? []).map(\.libraryFilter)
		)

		return .result()
	}
}
