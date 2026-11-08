//
//  ShowLibraryListIntent.swift
//  Ergo
//
//  Created by Adon Omeri on 5/11/2026.
//

import AppIntents

@AppIntent(.tool)
struct ShowLibraryListIntent: AppIntent {
	static let title: LocalizedStringResource = "Show Library List"

	static let description = IntentDescription(
		"Opens the list of one library category in Ergo: biases, concepts, fallacies, paradoxes, razors, arguments, philosophers, or logic symbols. Filters by tags, and for logic symbols also groups, replacing any filters already applied. Passing none removes all filters."
	)

	@Parameter(
		title: "Category",
		description: "The library category to show, such as biases or fallacies."
	)
	var category: LibraryContent

	@Parameter(
		title: "Filters",
		description: "Tags to filter by, such as memory or causal reasoning. For logic symbols this can also be a group, such as connective or quantifier. An item matches if it has any of these. Filters that belong to a different category are ignored. Philosophers have no filters."
	)
	var filters: [LibraryTagValue]?

	static var parameterSummary: some ParameterSummary {
		Summary("Show \(\.$category)") {
			\.$filters
		}
	}

	@Dependency
	private var navigation: NavigationManager

	static let supportedModes: IntentModes = [
		.foreground(.immediate),
	]

	@MainActor
	func perform() async throws -> some IntentResult {
		let matching = (filters ?? [])
			.filter { $0.category == category }
			.map(\.libraryFilter)

		navigation.showLibraryList(category, filters: matching)

		return .result()
	}
}
