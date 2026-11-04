//
//  SymbolEntity.swift
//  Ergo
//
//  Created by Adon Omeri on 4/11/2026.
//

import AppIntents
import CoreSpotlight

struct SymbolEntity: IndexedEntity {
	static let typeDisplayRepresentation: TypeDisplayRepresentation = "Logic Symbol"

	static let defaultQuery = SymbolEntityQuery()

	let id: String

	@Property(title: "Name", indexingKey: \.displayName)
	var name: String

	@Property(title: "Glyph")
	var glyph: String

	@Property(title: "Alternate Glyphs")
	var alternateGlyphs: [String]

	@Property(title: "Also Known As", indexingKey: \.keywords)
	var aliases: [String]

	@Property(title: "Group")
	var group: SymbolGroup

	@Property(title: "Arity")
	var arity: Int

	@Property(title: "Shortcodes")
	var shortcodes: [String]

	@Property(title: "English Readings")
	var englishReadings: [String]

	@Property(title: "Summary", indexingKey: \.contentDescription)
	var summary: String

	@Property(title: "Body")
	var body: String

	@Property(title: "Examples")
	var examples: [String]

	@Property(title: "Limitations")
	var limitations: [String]

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
			subtitle: "\(glyph) · Logic Symbol",
			image: .init(systemName: LibraryContent.symbols.symbol)
		)
	}

	init(_ symbol: LogicSymbol) {
		let examples = symbol.examples.map(\.entityText)
		let lookalikes = symbol.lookalikes.map(\.entityText)
		let related = symbol.related.map(\.name)
		let tags = symbol.tags.map(\.title)

		id = symbol.id
		name = symbol.name
		glyph = symbol.glyph
		alternateGlyphs = symbol.alternateGlyphs
		aliases = symbol.aliases
		group = symbol.group
		arity = symbol.arity
		shortcodes = symbol.shortcodes
		englishReadings = symbol.englishReadings
		summary = symbol.summary
		body = symbol.body
		self.examples = examples
		limitations = symbol.limitations
		self.lookalikes = lookalikes
		relatedEntries = related
		self.tags = tags
		fullText = EntityText.join([
			EntityText.field("Name", symbol.name),
			EntityText.field("Glyph", symbol.glyph),
			EntityText.section("Alternate glyphs", symbol.alternateGlyphs),
			EntityText.section("Also known as", symbol.aliases),
			EntityText.field("Group", symbol.group.rawValue.capitalized),
			EntityText.field("Arity", "\(symbol.arity)"),
			EntityText.section("Shortcodes", symbol.shortcodes),
			EntityText.section("English readings", symbol.englishReadings),
			symbol.summary,
			symbol.body,
			EntityText.section("Examples", examples),
			EntityText.section("Limitations", symbol.limitations),
			EntityText.section("Lookalikes", lookalikes),
			EntityText.section("Related", related),
			EntityText.section("Tags", tags),
		])
	}
}
