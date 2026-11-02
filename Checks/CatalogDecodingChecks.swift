// Run with Xcode MCP RunCodeSnippet in the context of CatalogStore.swift.
// This file is outside the app target; it checks the actual app models and bundle.
import Foundation

func expectCatalogFailure(_ operation: () throws -> Void) {
	var rejected = false
	do {
		try operation()
	} catch {
		rejected = true
	}
	precondition(rejected, "Invalid catalog data was accepted")
}

let store = await CatalogStore()
try await store.load()
var references: [CatalogReference] = []
await references.append(contentsOf: store.biases.biases.flatMap(\.related))
await references.append(contentsOf: store.concepts.concepts.flatMap(\.related))
await references.append(contentsOf: store.fallacies.fallacies.flatMap(\.related))
await references.append(contentsOf: store.razors.razors.flatMap(\.related))
await references.append(contentsOf: store.logicSymbols.symbols.flatMap(\.related))
await references.append(contentsOf: store.paradoxes.paradoxes.flatMap(\.related))
await references.append(contentsOf: store.philosophers.philosophers.flatMap(\.related))
await references.append(contentsOf: store.arguments.arguments.flatMap(\.related))
await references.append(contentsOf: store.concepts.concepts.flatMap(\.keyFigures))
await references.append(contentsOf: store.paradoxes.paradoxes.flatMap(\.keyFigures))
await references.append(contentsOf: store.arguments.arguments.flatMap(\.keyFigures))
await references.append(contentsOf: store.biases.biases.flatMap(\.lookalikes).map(\.target))
await references.append(contentsOf: store.concepts.concepts.flatMap(\.lookalikes).map(\.target))
await references.append(contentsOf: store.fallacies.fallacies.flatMap(\.lookalikes).map(\.target))
await references.append(contentsOf: store.logicSymbols.symbols.flatMap(\.lookalikes).map(\.target))
await references.append(contentsOf: store.paradoxes.paradoxes.flatMap(\.lookalikes).map(\.target))
let index = await store.index
for reference in references {
	let resolved = try index.reference(for: reference.id)
	precondition(resolved == reference)
}

let decoder = JSONDecoder()
decoder.userInfo[.catalogIndex] = index
let reference = try decoder.decode(CatalogReference.self, from: Data("\"because-marker\"".utf8))
precondition(reference.name == "Because marker")
precondition(reference.category == .symbols)

expectCatalogFailure {
	_ = try decoder.decode(CatalogReference.self, from: Data("\"missing-catalog-item\"".utf8))
}

expectCatalogFailure {
	_ = try decoder.decode(CatalogReference.self, from: Data("{\"id\":\"missing-catalog-item\"}".utf8))
}

expectCatalogFailure {
	_ = try decoder.decode(CatalogLink.self, from: Data("{\"targetID\":\"missing-catalog-item\",\"note\":\"Example\"}".utf8))
}

expectCatalogFailure {
	_ = try JSONDecoder().decode(CatalogReference.self, from: Data("\"because-marker\"".utf8))
}

let link = try decoder.decode(CatalogLink.self, from: Data("{\"targetID\":\"because-marker\",\"note\":\"Example\"}".utf8))
precondition(link.target == reference)
precondition(link.note == "Example")

// Bookmark objects retain their original Codable shape without an index.
let bookmarkData = try JSONEncoder().encode(reference)
let bookmark = try JSONDecoder().decode(CatalogReference.self, from: bookmarkData)
precondition(bookmark == reference)
let bookmarkObject = try JSONSerialization.jsonObject(with: bookmarkData) as! [String: Any]
precondition(Set(bookmarkObject.keys) == ["id", "name", "category"])
let canonical = try decoder.decode(CatalogReference.self, from: Data("{\"id\":\"because-marker\",\"name\":\"Wrong name\"}".utf8))
precondition(canonical == reference)

func checkTag(_ type: (some Decodable).Type) {
	expectCatalogFailure {
		_ = try JSONDecoder().decode(type, from: Data("\"unknown-tag\"".utf8))
	}
}

checkTag(BiasTag.self)
checkTag(ConceptTag.self)
checkTag(FallacyTag.self)
checkTag(RazorTag.self)
checkTag(SymbolTag.self)
checkTag(ParadoxTag.self)
checkTag(ArgumentTag.self)
expectCatalogFailure {
	_ = try JSONDecoder().decode(ParadoxTag.self, from: Data("\"thought-experiments\"".utf8))
}

expectCatalogFailure {
	_ = try JSONDecoder().decode(ConceptTag.self, from: Data("\"metaphysics\"".utf8))
}

var duplicateIndex = CatalogIndex()
try duplicateIndex.register([reference], category: .symbols, id: \.id, name: \.name)
expectCatalogFailure {
	try duplicateIndex.register([reference], category: .symbols, id: \.id, name: \.name)
}

for argument in await store.arguments.arguments {
	let reference = CatalogReference(id: argument.id, name: argument.name, category: .arguments)
	precondition(reference.route == .detail(category: .arguments, id: argument.id))
}

print("Catalog checks passed: all eight catalogs loaded, \(references.count) references verified, invalid references/tags rejected, bookmarks preserved.")
