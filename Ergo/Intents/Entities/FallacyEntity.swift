//
//  FallacyEntity.swift
//  Ergo
//
//  Created by Adon Omeri on 4/11/2026.
//

import AppIntents
import CoreSpotlight

struct FallacyEntity: IndexedEntity {
	static let typeDisplayRepresentation: TypeDisplayRepresentation = "Fallacy"

	static let defaultQuery = FallacyEntityQuery()

	let id: String

	@Property(title: "Name", indexingKey: \.displayName)
	var name: String

	@Property(title: "Also Known As", indexingKey: \.keywords)
	var aliases: [String]

	@Property(title: "Summary", indexingKey: \.contentDescription)
	var summary: String

	@Property(title: "Body")
	var body: String

	@Property(title: "Detection Criteria")
	var detectionCriteria: String?

	@Property(title: "Examples")
	var examples: [String]

	@Property(title: "Does Not Count When")
	var doesNotCountWhen: [String]

	@Property(title: "Lookalikes")
	var lookalikes: [String]

	@Property(title: "Related Entries")
	var relatedEntries: [String]

	@Property(title: "Tags")
	var tags: [String]

	@Property(title: "Full Text", indexingKey: \.textContent)
	var fullText: String

	var displayRepresentation: DisplayRepresentation {
		DisplayRepresentation(
			title: "\(name)",
			subtitle: "Fallacy",
			image: .init(systemName: LibraryContent.fallacies.symbol)
		)
	}

	init(_ fallacy: Fallacy) {
		let examples = fallacy.examples.map(\.entityText)
		let lookalikes = fallacy.lookalikes.map(\.entityText)
		let related = fallacy.related.map(\.name)
		let tags = fallacy.tags.map(\.title)

		id = fallacy.id
		name = fallacy.name
		aliases = fallacy.aliases
		summary = fallacy.summary
		body = fallacy.body
		detectionCriteria = fallacy.detectionCriteria
		self.examples = examples
		doesNotCountWhen = fallacy.doesNotCountWhen
		self.lookalikes = lookalikes
		relatedEntries = related
		self.tags = tags
		fullText = EntityText.join([
			EntityText.field("Name", fallacy.name),
			EntityText.section("Also known as", fallacy.aliases),
			fallacy.summary,
			fallacy.body,
			EntityText.field("Detection criteria", fallacy.detectionCriteria),
			EntityText.section("Examples", examples),
			EntityText.section("Does not count when", fallacy.doesNotCountWhen),
			EntityText.section("Lookalikes", lookalikes),
			EntityText.section("Related", related),
			EntityText.section("Tags", tags),
		])
	}
}
