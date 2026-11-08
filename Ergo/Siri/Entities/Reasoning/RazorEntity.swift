//
//  RazorEntity.swift
//  Ergo
//
//  Created by Adon Omeri on 4/11/2026.
//

import AppIntents
import CoreSpotlight

struct RazorEntity: IndexedEntity {
	static let typeDisplayRepresentation: TypeDisplayRepresentation = "Razor"

	static let defaultQuery = RazorEntityQuery()

	let id: String

	@Property(title: "Name", indexingKey: \.displayName)
	var name: String

	@Property(title: "Also Known As", indexingKey: \.keywords)
	var aliases: [String]

	@Property(title: "Summary", indexingKey: \.contentDescription)
	var summary: String

	@Property(title: "Body")
	var body: String

	@Property(title: "Lens Question")
	var lensQuestion: String

	@Property(title: "Examples")
	var examples: [String]

	@Property(title: "Limitations")
	var limitations: [String]

	@Property(title: "Related Entries")
	var relatedEntries: [String]

	@Property(title: "Tags")
	var tags: [String]

	@Property(title: "Full Text", indexingKey: \.textContent)
	var fullText: String

	var displayRepresentation: DisplayRepresentation {
		DisplayRepresentation(
			title: "\(name)",
			subtitle: "Razor",
			image: .init(systemName: LibraryContent.razors.symbol)
		)
	}

	init(_ razor: Razor) {
		let examples = razor.examples.map(\.entityText)
		let related = razor.related.map(\.name)
		let tags = razor.tags.map(\.title)

		id = razor.id
		name = razor.name
		aliases = razor.aliases
		summary = razor.summary
		body = razor.body
		lensQuestion = razor.lensQuestion
		self.examples = examples
		limitations = razor.limitations
		relatedEntries = related
		self.tags = tags
		fullText = EntityText.join([
			EntityText.field("Name", razor.name),
			EntityText.section("Also known as", razor.aliases),
			razor.summary,
			razor.body,
			EntityText.field("Lens question", razor.lensQuestion),
			EntityText.section("Examples", examples),
			EntityText.section("Limitations", razor.limitations),
			EntityText.section("Related", related),
			EntityText.section("Tags", tags),
		])
	}
}
