//
//  ArgumentEntity.swift
//  Ergo
//
//  Created by Adon Omeri on 4/11/2026.
//

import AppIntents
import CoreSpotlight

struct ArgumentEntity: IndexedEntity {
	static let typeDisplayRepresentation: TypeDisplayRepresentation = "Argument"

	static let defaultQuery = ArgumentEntityQuery()

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

	@Property(title: "Premises")
	var premises: [String]

	@Property(title: "Conclusion")
	var conclusion: String

	@Property(title: "Assumptions")
	var assumptions: [String]

	@Property(title: "Objections")
	var objections: [String]

	@Property(title: "Examples")
	var examples: [String]

	@Property(title: "Related Entries")
	var relatedEntries: [String]

	@Property(title: "Tags")
	var tags: [String]

	@Property(title: "Full Text", indexingKey: \.textContent)
	var fullText: String

	var displayRepresentation: DisplayRepresentation {
		DisplayRepresentation(
			title: "\(name)",
			subtitle: "Argument",
			image: .init(systemName: LibraryContent.arguments.symbol)
		)
	}

	init(_ argument: Argument) {
		let keyFigures = argument.keyFigures.map(\.name)
		let objections = argument.objections.map(\.entityText)
		let examples = argument.examples.map(\.entityText)
		let related = argument.related.map(\.name)
		let tags = argument.tags.map(\.title)

		id = argument.id
		name = argument.name
		aliases = argument.aliases
		summary = argument.summary
		body = argument.body
		origin = argument.origin
		self.keyFigures = keyFigures
		premises = argument.premises
		conclusion = argument.conclusion
		assumptions = argument.assumptions
		self.objections = objections
		self.examples = examples
		relatedEntries = related
		self.tags = tags
		fullText = EntityText.join([
			EntityText.field("Name", argument.name),
			EntityText.section("Also known as", argument.aliases),
			argument.summary,
			argument.body,
			EntityText.field("Origin", argument.origin),
			EntityText.section("Key figures", keyFigures),
			EntityText.section("Premises", argument.premises),
			EntityText.field("Conclusion", argument.conclusion),
			EntityText.section("Assumptions", argument.assumptions),
			EntityText.section("Objections", objections),
			EntityText.section("Examples", examples),
			EntityText.section("Related", related),
			EntityText.section("Tags", tags),
		])
	}
}
