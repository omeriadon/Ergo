//
//  PhilosopherEntity.swift
//  Ergo
//
//  Created by Adon Omeri on 4/11/2026.
//

import AppIntents
import CoreSpotlight

struct PhilosopherEntity: IndexedEntity {
	static let typeDisplayRepresentation: TypeDisplayRepresentation = "Philosopher"

	static let defaultQuery = PhilosopherEntityQuery()

	let id: String

	@Property(title: "Name", indexingKey: \.displayName)
	var name: String

	@Property(title: "Summary", indexingKey: \.contentDescription)
	var summary: String

	@Property(title: "Body")
	var body: String

	@Property(title: "Birth Year")
	var birthYear: Int

	@Property(title: "Death Year")
	var deathYear: Int?

	@Property(title: "Lifespan")
	var lifespan: String

	@Property(title: "Related Entries")
	var relatedEntries: [String]

	@Property(title: "Full Text", indexingKey: \.textContent)
	var fullText: String

	var displayRepresentation: DisplayRepresentation {
		DisplayRepresentation(
			title: "\(name)",
			subtitle: "\(lifespan)",
			image: .init(systemName: LibraryContent.philosophers.symbol)
		)
	}

	init(_ philosopher: Philosopher) {
		let lifespan = Self.lifespan(
			birth: philosopher.birthYear,
			death: philosopher.deathYear
		)
		let related = philosopher.related.map(\.name)

		id = philosopher.id
		name = philosopher.name
		summary = philosopher.summary
		body = philosopher.body
		birthYear = philosopher.birthYear
		deathYear = philosopher.deathYear
		self.lifespan = lifespan
		relatedEntries = related
		fullText = EntityText.join([
			EntityText.field("Name", philosopher.name),
			EntityText.field("Lifespan", lifespan),
			philosopher.summary,
			philosopher.body,
			EntityText.section("Related", related),
		])
	}

	private static func lifespan(birth: Int, death: Int?) -> String {
		guard let death else {
			return "born \(yearText(birth))"
		}

		return "\(yearText(birth)) – \(yearText(death))"
	}

	private static func yearText(_ year: Int) -> String {
		year < 0 ? "\(-year) BCE" : "\(year)"
	}
}
