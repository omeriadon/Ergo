//
//  BiasEntity.swift
//  Ergo
//
//  Created by Adon Omeri on 4/11/2026.
//

import AppIntents
import CoreSpotlight

struct BiasEntity: IndexedEntity {
	static let typeDisplayRepresentation: TypeDisplayRepresentation = "Cognitive Bias"

	static let defaultQuery = BiasEntityQuery()

	let id: String

	@Property(title: "Name", indexingKey: \.displayName)
	var name: String

	@Property(title: "Also Known As", indexingKey: \.keywords)
	var aliases: [String]

	@Property(title: "Summary", indexingKey: \.contentDescription)
	var summary: String

	@Property(title: "Body")
	var body: String

	@Property(title: "Examples")
	var examples: [String]

	@Property(title: "Counters")
	var counters: [String]

	@Property(title: "Limitations")
	var limitations: [String]

	@Property(title: "Evidence Note")
	var evidenceNote: String?

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
			subtitle: "Cognitive Bias",
			image: .init(systemName: LibraryContent.biases.symbol)
		)
	}

	init(_ bias: Bias) {
		let examples = bias.examples.map(\.entityText)
		let lookalikes = bias.lookalikes.map(\.entityText)
		let related = bias.related.map(\.name)
		let tags = bias.tags.map(\.title)

		id = bias.id
		name = bias.name
		aliases = bias.aliases
		summary = bias.summary
		body = bias.body
		self.examples = examples
		counters = bias.counters
		limitations = bias.limitations
		evidenceNote = bias.evidenceNote
		self.lookalikes = lookalikes
		relatedEntries = related
		self.tags = tags
		fullText = EntityText.join([
			EntityText.field("Name", bias.name),
			EntityText.section("Also known as", bias.aliases),
			bias.summary,
			bias.body,
			EntityText.section("Examples", examples),
			EntityText.section("Counters", bias.counters),
			EntityText.section("Limitations", bias.limitations),
			EntityText.field("Evidence note", bias.evidenceNote),
			EntityText.section("Lookalikes", lookalikes),
			EntityText.section("Related", related),
			EntityText.section("Tags", tags),
		])
	}
}
