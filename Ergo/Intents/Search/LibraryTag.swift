//
//  LibraryTag.swift
//  Ergo
//
//  Created by Adon Omeri on 4/11/2026.
//

import Foundation

protocol LibraryTag: CaseIterable, RawRepresentable where RawValue == String {
	var title: String { get }
}

extension BiasTag: LibraryTag {}
extension RazorTag: LibraryTag {}
extension ParadoxTag: LibraryTag {}
extension ConceptTag: LibraryTag {}
extension FallacyTag: LibraryTag {}
extension ArgumentTag: LibraryTag {}
extension SymbolTag: LibraryTag {}

extension String {
	var normalizedTagText: String {
		replacingOccurrences(of: "-", with: " ")
			.replacingOccurrences(of: "&", with: " and ")
			.lowercased()
			.filter { $0.isLetter || $0.isNumber || $0 == " " }
			.split(separator: " ")
			.joined(separator: " ")
	}
}

extension LibraryTag {
	static func match(_ term: String) -> Self? {
		let normalized = term.normalizedTagText

		return allCases.first { tag in
			tag.title.normalizedTagText == normalized
				|| tag.rawValue.normalizedTagText == normalized
		}
	}
}
