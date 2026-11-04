//
//  ParadoxEntity.swift
//  Ergo
//
//  Created by Adon Omeri on 4/11/2026.
//

import AppIntents
import CoreSpotlight

struct ParadoxEntity: IndexedEntity {
	static let typeDisplayRepresentation: TypeDisplayRepresentation = "Paradox"

	static let defaultQuery = ParadoxEntityQuery()

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
			subtitle: "Paradox",
			image: .init(systemName: LibraryContent.paradoxes.symbol)
		)
	}

	init(_ paradox: Paradox) {
		let keyFigures = paradox.keyFigures.map(\.name)
		let examples = paradox.examples.map(\.entityText)
		let lookalikes = paradox.lookalikes.map(\.entityText)
		let related = paradox.related.map(\.name)
		let tags = paradox.tags.map(\.title)

		id = paradox.id
		name = paradox.name
		aliases = paradox.aliases
		summary = paradox.summary
		body = paradox.body
		origin = paradox.origin
		self.keyFigures = keyFigures
		self.examples = examples
		commonMisreadings = paradox.commonMisreadings
		criticisms = paradox.criticisms
		self.lookalikes = lookalikes
		relatedEntries = related
		self.tags = tags
		fullText = EntityText.join([
			EntityText.field("Name", paradox.name),
			EntityText.section("Also known as", paradox.aliases),
			paradox.summary,
			paradox.body,
			EntityText.field("Origin", paradox.origin),
			EntityText.section("Key figures", keyFigures),
			EntityText.section("Examples", examples),
			EntityText.section("Common misreadings", paradox.commonMisreadings),
			EntityText.section("Criticisms", paradox.criticisms),
			EntityText.section("Lookalikes", lookalikes),
			EntityText.section("Related", related),
			EntityText.section("Tags", tags),
		])
	}
}
