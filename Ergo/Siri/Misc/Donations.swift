//
//  Donations.swift
//  Ergo
//
//  Created by Adon Omeri on 6/11/2026.
//

import AppIntents

/// Tells the system about library actions the user did themselves, so Siri, Spotlight and Shortcuts can learn and suggest them.
///
/// Only call these from the view layer's own handlers, never from an intent's `perform()` or from a `NavigationManager` method an intent calls: the system already donates what it runs itself, and donating that again would feed back into the suggestions.
/// Only library browsing is donated. Nothing from the Check tab (English or logic text) goes through here.
enum IntentDonations {
	// MARK: - Tabs

	static func tab(_ tab: AppTab) {
		let intent = OpenTabIntent()
		intent.tab = tab
		donate(intent)
	}

	// MARK: - Navigation

	/// Donates the push the user just made onto the library path.
	static func route(_ route: LibraryRoute, catalog: CatalogStore) {
		switch route {
			case let .category(category):
				libraryList(category, filters: [])

			case let .detail(category, id):
				openEntry(category: category, id: id, catalog: catalog)

			case let .symbols(filter):
				libraryList(.symbols, filters: [filter.libraryFilter])

			case let .biases(filter):
				libraryList(.biases, filters: [filter.libraryFilter])

			case let .razors(filter):
				libraryList(.razors, filters: [filter.libraryFilter])

			case let .paradoxes(filter):
				libraryList(.paradoxes, filters: [filter.libraryFilter])

			case let .concepts(filter):
				libraryList(.concepts, filters: [filter.libraryFilter])

			case let .fallacies(filter):
				libraryList(.fallacies, filters: [filter.libraryFilter])

			case let .arguments(filter):
				libraryList(.arguments, filters: [filter.libraryFilter])

			case .bookmarks:
				donate(OpenBookmarksIntent())
		}
	}

	static func libraryList(_ category: LibraryContent, filters: [LibraryFilter]) {
		let intent = ShowLibraryListIntent()
		intent.category = category

		let values = filters.compactMap { LibraryTagValue.value(for: $0, in: category) }
		intent.filters = values.isEmpty ? nil : values

		donate(intent)
	}

	static func clearFilters() {
		donate(ClearLibraryFiltersIntent())
	}

	// MARK: - Search

	/// For a search the user committed (return key), not one they are still typing.
	static func search(_ query: String) {
		let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

		guard !trimmed.isEmpty else {
			return
		}

		let intent = SearchLibraryIntent()
		intent.criteria = StringSearchCriteria(term: trimmed)
		donate(intent)
	}

	// MARK: - Bookmarks

	static func bookmark(_ reference: CatalogReference, added: Bool, catalog: CatalogStore) {
		guard let entry = entry(category: reference.category, id: reference.id, catalog: catalog) else {
			return
		}

		let intent = SetBookmarkIntent()
		intent.item = entry
		intent.action = added ? .add : .remove
		donate(intent)
	}

	// MARK: - Entries

	private static func openEntry(category: LibraryContent, id: String, catalog: CatalogStore) {
		guard let entry = entry(category: category, id: id, catalog: catalog) else {
			return
		}

		// The typed Open<X>EntityIntents aren't discoverable, so donate the one open intent the system does see
		let intent = OpenLibraryEntryIntent()
		intent.target = entry
		donate(intent)
	}

	/// Nil when the catalog hasn't loaded or doesn't know the id; the donation is then skipped.
	private static func entry(category: LibraryContent, id: String, catalog: CatalogStore) -> LibraryEntry? {
		switch category {
			case .biases:
				catalog.biases.biases.first { $0.id == id }.map { .bias(BiasEntity($0)) }

			case .concepts:
				catalog.concepts.concepts.first { $0.id == id }.map { .concept(ConceptEntity($0)) }

			case .fallacies:
				catalog.fallacies.fallacies.first { $0.id == id }.map { .fallacy(FallacyEntity($0)) }

			case .paradoxes:
				catalog.paradoxes.paradoxes.first { $0.id == id }.map { .paradox(ParadoxEntity($0)) }

			case .razors:
				catalog.razors.razors.first { $0.id == id }.map { .razor(RazorEntity($0)) }

			case .arguments:
				catalog.arguments.arguments.first { $0.id == id }.map { .argument(ArgumentEntity($0)) }

			case .philosophers:
				catalog.philosophers.philosophers.first { $0.id == id }.map { .philosopher(PhilosopherEntity($0)) }

			case .symbols:
				catalog.logicSymbols.symbols.first { $0.id == id }.map { .symbol(SymbolEntity($0)) }
		}
	}

	// MARK: - Donating

	/// Fire and forget: a failed donation only means one less hint for the system, so the error is dropped.
	private static func donate(_ intent: some AppIntent) {
		Task {
			_ = try? await IntentDonationManager.shared.donate(intent: intent)
		}
	}
}
