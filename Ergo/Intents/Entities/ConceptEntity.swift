//
//  ConceptEntity.swift
//  Ergo
//
//  Created by Adon Omeri on 4/11/2026.
//

import AppIntents
import CoreSpotlight

struct ConceptEntity: IndexedEntity {
	static let typeDisplayRepresentation: TypeDisplayRepresentation = "Concept"

	static let defaultQuery = ConceptEntityQuery()

	let id: String

	@Property(title: "Name", indexingKey: \.displayName)
	var name: String

	@Property(title: "Also Known As", indexingKey: \.keywords)
	var aliases: [String]

	@Property(title: "Summary", indexingKey: \.contentDescription)
	var summary: String

	@Property(title: "Body")
	var body: String

	@Property(title: "Origin")
	var origin: String?

	@Property(title: "Key Figures")
	var keyFigures: [String]

	@Property(title: "Examples")
	var examples: [String]

	@Property(title: "Common Misreadings")
	var commonMisreadings: [String]

	@Property(title: "Criticisms")
	var criticisms: [String]

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
			subtitle: "Concept",
			image: .init(systemName: LibraryContent.concepts.symbol)
		)
	}

	init(_ concept: Concept) {
		let keyFigures = concept.keyFigures.map(\.name)
		let examples = concept.examples.map(\.entityText)
		let lookalikes = concept.lookalikes.map(\.entityText)
		let related = concept.related.map(\.name)
		let tags = concept.tags.map(\.title)

		id = concept.id
		name = concept.name
		aliases = concept.aliases
		summary = concept.summary
		body = concept.body
		origin = concept.origin
		self.keyFigures = keyFigures
		self.examples = examples
		commonMisreadings = concept.commonMisreadings
		criticisms = concept.criticisms
		self.lookalikes = lookalikes
		relatedEntries = related
		self.tags = tags
		fullText = EntityText.join([
			EntityText.field("Name", concept.name),
			EntityText.section("Also known as", concept.aliases),
			concept.summary,
			concept.body,
			EntityText.field("Origin", concept.origin),
			EntityText.section("Key figures", keyFigures),
			EntityText.section("Examples", examples),
			EntityText.section("Common misreadings", concept.commonMisreadings),
			EntityText.section("Criticisms", concept.criticisms),
			EntityText.section("Lookalikes", lookalikes),
			EntityText.section("Related", related),
			EntityText.section("Tags", tags),
		])
	}
}
