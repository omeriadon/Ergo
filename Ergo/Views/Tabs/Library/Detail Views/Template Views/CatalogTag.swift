import Foundation

struct CatalogTag: Identifiable, Hashable, Sendable {
	let id: String
	let title: String
	let route: LibraryRoute
}
