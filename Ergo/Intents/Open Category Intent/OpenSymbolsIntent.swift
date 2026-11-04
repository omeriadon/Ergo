
import AppIntents

@AppIntent(.tool)
struct OpenSymbolsIntent: AppIntent {
	static let title: LocalizedStringResource = "Show Logic Symbols"

	static let description = IntentDescription(
		"Opens the list of logic symbols in Ergo. Filters by tags and groups, replacing any filters already applied. Passing none removes all filters."
	)

	@Parameter(
		title: "Tags",
		description: "Notation tags to filter by, such as modal logic or set notation. A symbol matches if it has any of these tags."
	)
	var tags: [SymbolTag]?

	@Parameter(
		title: "Groups",
		description: "Symbol groups to filter by, such as connective or quantifier. A symbol matches if it is in any of these groups."
	)
	var groups: [SymbolGroup]?

	static var parameterSummary: some ParameterSummary {
		Summary("Show logic symbols") {
			\.$tags
			\.$groups
		}
	}

	@Dependency
	private var navigation: NavigationManager

	static var supportedModes: IntentModes = [
		.foreground(.immediate),
	]

	@MainActor
	func perform() async throws -> some IntentResult {
		let groupFilters = (groups ?? []).map(\.libraryFilter)
		let tagFilters = (tags ?? []).map(\.libraryFilter)

		navigation.showLibraryList(
			.symbols,
			filters: groupFilters + tagFilters
		)

		return .result()
	}
}
