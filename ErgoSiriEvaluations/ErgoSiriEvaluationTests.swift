//
//  ErgoSiriEvaluationTests.swift
//  ErgoSiriEvaluations
//
//  Created by Adon Omeri on 6/11/2026.
//

import SiriEvaluations
import Testing

/// Measures how well Siri picks and fills in Ergo's App Intents. Names are strings because the test
/// bundle can't link the app: they are the Swift type names from `Ergo/Siri/`.
@Suite("Ergo - Siri", .serialized)
struct ErgoSiriEvaluationTests {
	static let appDefinitions = IntentDefinitions(bundleIdentifier: "com.adonis.Ergo")

	// Intents. The typed Open<X>EntityIntents are not here: they are plain `OpenIntent`s for Spotlight,
	// not tools and not discoverable, so Siri never calls them.
	static let OpenTabIntent = appDefinitions.intents["OpenTabIntent"]
	static let ShowLibraryListIntent = appDefinitions.intents["ShowLibraryListIntent"]
	static let OpenLibraryEntryIntent = appDefinitions.intents["OpenLibraryEntryIntent"]
	static let SearchLibraryIntent = appDefinitions.intents["SearchLibraryIntent"]
	static let OpenBookmarksIntent = appDefinitions.intents["OpenBookmarksIntent"]
	static let SetBookmarkIntent = appDefinitions.intents["SetBookmarkIntent"]

	// Entities
	static let FallacyEntity = appDefinitions.entities["FallacyEntity"]
	static let BiasEntity = appDefinitions.entities["BiasEntity"]
	static let ConceptEntity = appDefinitions.entities["ConceptEntity"]
	static let ParadoxEntity = appDefinitions.entities["ParadoxEntity"]
	static let RazorEntity = appDefinitions.entities["RazorEntity"]
	static let ArgumentEntity = appDefinitions.entities["ArgumentEntity"]
	static let PhilosopherEntity = appDefinitions.entities["PhilosopherEntity"]
	static let SymbolEntity = appDefinitions.entities["SymbolEntity"]

	// Ergo ships no App Skills (no *.skillsbundle), so there is no `Loads` expectation anywhere.

	// MARK: - Opening tabs

	/// The AppEnum parameter is matched with `.equals` on the case's raw value ("library"). Unverified
	/// until run on a device: there is no AppEnum-specific matcher.
	static let openLibraryTab = SiriScenario {
		UserTurn("In Ergo, open the Library tab") {
			Calls {
				OpenTabIntent.expect(tab: .equals("library"))
			}
		}
	}

	static let openDebateTab = SiriScenario {
		UserTurn("Switch to the Debate tab in Ergo") {
			Calls {
				OpenTabIntent.expect(tab: .equals("debate"))
			}
		}
	}

	static let openCheckTab = SiriScenario {
		UserTurn("Take me to the Check tab in Ergo") {
			Calls {
				OpenTabIntent.expect(tab: .equals("check"))
			}
		}
	}

	static let tabsEvaluation = ErgoEvaluation(
		name: "Ergo - Open tabs",
		dataset: SiriScenarioLoader { openLibraryTab; openDebateTab; openCheckTab }
	)

	@Test("Siri opens the requested Ergo tab", .evaluates(tabsEvaluation))
	func opensTabs() {
		let result = EvaluationContext.current.result
		#expect(result.aggregateValue(.mean(of: .intentsAllPass)) == 1.0)
	}

	// MARK: - Showing a library category

	/// Same caveat as the tabs: `category` is an AppEnum matched by raw value.
	static let showFallacies = SiriScenario {
		UserTurn("In Ergo, show me the list of fallacies") {
			Calls {
				ShowLibraryListIntent.expect(category: .equals("fallacies"))
			}
		}
	}

	static let showBiases = SiriScenario {
		UserTurn("In Ergo, show all the cognitive biases") {
			Calls {
				ShowLibraryListIntent.expect(category: .equals("biases"))
			}
		}
	}

	static let showPhilosophers = SiriScenario {
		UserTurn("Show the philosophers in Ergo") {
			Calls {
				ShowLibraryListIntent.expect(category: .equals("philosophers"))
			}
		}
	}

	static let showRazors = SiriScenario {
		UserTurn("Open the razors list in Ergo") {
			Calls {
				ShowLibraryListIntent.expect(category: .equals("razors"))
			}
		}
	}

	static let showSymbols = SiriScenario {
		UserTurn("In Ergo, show the logic symbols") {
			Calls {
				ShowLibraryListIntent.expect(category: .equals("symbols"))
			}
		}
	}

	static let categoriesEvaluation = ErgoEvaluation(
		name: "Ergo - Show a library category",
		dataset: SiriScenarioLoader { showFallacies; showBiases; showPhilosophers; showRazors; showSymbols }
	)

	@Test("Siri shows the requested library category", .evaluates(categoriesEvaluation))
	func showsCategories() {
		let result = EvaluationContext.current.result
		#expect(result.aggregateValue(.mean(of: .intentsAllPass)) == 1.0)
	}

	// MARK: - Opening a specific entry

	/// OpenLibraryEntryIntent is the only open intent Siri can call. Its `target` is a union of every
	/// entity type, so it can't be constrained: `Finds` checks that Siri resolved the named entity
	/// instead. The user only asked to open, so nothing may touch bookmarks.
	static func openOnly(_ utterance: String, finding entity: AppEntityExpectationProviding) -> SiriScenario {
		SiriScenario {
			UserTurn(utterance) {
				Calls { OpenLibraryEntryIntent }
				Finds { entity }
				Calls(.disallowed) { SetBookmarkIntent }
			}
		}
	}

	static let entriesEvaluation = ErgoEvaluation(
		name: "Ergo - Open an entry by name",
		dataset: SiriScenarioLoader {
			openOnly(
				"In Ergo, open the ad hominem fallacy",
				finding: FallacyEntity.expectIdentifier("ad-hominem")
			)
			openOnly(
				"Open the straw man fallacy in Ergo",
				finding: FallacyEntity.expectIdentifier("straw-man")
			)
			openOnly(
				"In Ergo, open confirmation bias",
				finding: BiasEntity.expectIdentifier("confirmation-bias")
			)
			openOnly(
				"In Ergo, open Occam's razor",
				finding: RazorEntity.expectIdentifier("occams-razor")
			)
			openOnly(
				"In Ergo, open Plato",
				finding: PhilosopherEntity.expectIdentifier("plato")
			)
			openOnly(
				"Show me Socrates in Ergo",
				finding: PhilosopherEntity.expectIdentifier("socrates")
			)
		}
	)

	@Test("Siri opens fallacies, biases, razors and philosophers by name", .evaluates(entriesEvaluation))
	func opensEntries() {
		let result = EvaluationContext.current.result
		#expect(result.aggregateValue(.mean(of: .intentsAllPass)) == 1.0)
		#expect(result.aggregateValue(.mean(of: .foundEntitiesAllPass)) == 1.0)
	}

	static let otherEntriesEvaluation = ErgoEvaluation(
		name: "Ergo - Open a concept, paradox, argument or symbol",
		dataset: SiriScenarioLoader {
			openOnly(
				"In Ergo, open abductive reasoning",
				finding: ConceptEntity.expectIdentifier("abductive-reasoning")
			)
			openOnly(
				"Open the Allais paradox in Ergo",
				finding: ParadoxEntity.expectIdentifier("paradox-allais-paradox")
			)
			openOnly(
				"In Ergo, open the argument from contingency",
				finding: ArgumentEntity.expectIdentifier("argument-contingency")
			)
			openOnly(
				"In Ergo, open the always operator",
				finding: SymbolEntity.expectIdentifier("always-operator")
			)
		}
	)

	@Test("Siri opens concepts, paradoxes, arguments and symbols by name", .evaluates(otherEntriesEvaluation))
	func opensOtherEntries() {
		let result = EvaluationContext.current.result
		#expect(result.aggregateValue(.mean(of: .intentsAllPass)) == 1.0)
		#expect(result.aggregateValue(.mean(of: .foundEntitiesAllPass)) == 1.0)
	}

	// MARK: - Bookmarks

	/// `item` is a union value, so only the call and its `action` are constrained; `Finds` checks Siri
	/// resolved the named entry. `action` is an AppEnum, matched by raw value like the tabs (unverified
	/// until run on a device). The two scenarios use the same entry so a full run leaves the bookmarks
	/// as it found them.
	static let addBookmark = SiriScenario {
		UserTurn("In Ergo, bookmark the ad hominem fallacy") {
			Calls { SetBookmarkIntent.expect(action: .equals("add")) }
			Finds { FallacyEntity.expectIdentifier("ad-hominem") }
			Calls(.disallowed) { SetBookmarkIntent.expect(action: .equals("remove")) }
		}
	}

	static let removeBookmark = SiriScenario {
		UserTurn("In Ergo, remove the ad hominem fallacy from my bookmarks") {
			Calls { SetBookmarkIntent.expect(action: .equals("remove")) }
			Finds { FallacyEntity.expectIdentifier("ad-hominem") }
			Calls(.disallowed) { SetBookmarkIntent.expect(action: .equals("add")) }
		}
	}

	static let bookmarkEditsEvaluation = ErgoEvaluation(
		name: "Ergo - Add and remove a bookmark",
		dataset: SiriScenarioLoader { addBookmark; removeBookmark }
	)

	@Test("Siri adds and removes the named bookmark", .evaluates(bookmarkEditsEvaluation))
	func editsBookmarks() {
		let result = EvaluationContext.current.result
		#expect(result.aggregateValue(.mean(of: .intentsAllPass)) == 1.0)
		#expect(result.aggregateValue(.mean(of: .foundEntitiesAllPass)) == 1.0)
	}

	static let openBookmarks = SiriScenario {
		UserTurn("In Ergo, show my bookmarks") {
			Calls { OpenBookmarksIntent }
			Calls(.disallowed) { SetBookmarkIntent }
		}
	}

	static let openBookmarksEvaluation = ErgoEvaluation(
		name: "Ergo - Open bookmarks",
		dataset: SiriScenarioLoader { openBookmarks }
	)

	@Test("Siri opens the bookmarks list", .evaluates(openBookmarksEvaluation))
	func opensBookmarks() {
		let result = EvaluationContext.current.result
		#expect(result.aggregateValue(.mean(of: .intentsAllPass)) == 1.0)
	}

	// MARK: - Searching the library

	/// SearchLibraryIntent is the system search-in-app schema and the only search intent. Its `criteria`
	/// is not constrained, so these only measure that Siri picks it.
	static let searchHominem = SiriScenario {
		UserTurn("In Ergo, search the library for hominem") {
			Calls { SearchLibraryIntent }
		}
	}

	static let searchAristotle = SiriScenario {
		UserTurn("Search for Aristotle in Ergo") {
			Calls { SearchLibraryIntent }
		}
	}

	static let searchConfirmationBias = SiriScenario {
		UserTurn("In Ergo, search for confirmation bias") {
			Calls { SearchLibraryIntent }
		}
	}

	static let searchEvaluation = ErgoEvaluation(
		name: "Ergo - Search the library",
		dataset: SiriScenarioLoader { searchHominem; searchAristotle; searchConfirmationBias }
	)

	@Test("Siri searches the library with the system search intent", .evaluates(searchEvaluation))
	func searchesLibrary() {
		let result = EvaluationContext.current.result
		#expect(result.aggregateValue(.mean(of: .intentsAllPass)) == 1.0)
	}

	// MARK: - Requests Ergo shouldn't handle

	/// Nothing here maps to an Ergo intent, so no intent may run. "Settings" is not an AppTab.
	static let unrelatedRequest = SiriScenario {
		UserTurn("In Ergo, order me a pizza") {
			Calls(.disallowed) {
				OpenTabIntent
				ShowLibraryListIntent
				OpenLibraryEntryIntent
				SearchLibraryIntent
				SetBookmarkIntent
			}
		}
	}

	static let missingTab = SiriScenario {
		UserTurn("In Ergo, open the Settings tab") {
			Calls(.disallowed) { OpenTabIntent }
		}
	}

	static let negativeEvaluation = ErgoEvaluation(
		name: "Ergo - Requests Ergo can't handle",
		dataset: SiriScenarioLoader { unrelatedRequest; missingTab }
	)

	@Test("Siri doesn't call an Ergo intent for an unsupported request", .evaluates(negativeEvaluation))
	func ignoresUnsupportedRequests() {
		let result = EvaluationContext.current.result
		#expect(result.aggregateValue(.mean(of: .intentsAllPass)) == 1.0)
	}
}
