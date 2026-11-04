//
//  EntityText.swift
//  Ergo
//
//  Created by Adon Omeri on 4/11/2026.
//

nonisolated enum EntityText {
	static func field(_ title: String, _ value: String?) -> String? {
		guard let value, !value.isEmpty else {
			return nil
		}

		return "\(title): \(value)"
	}

	static func section(_ title: String, _ items: [String]) -> String? {
		guard !items.isEmpty else {
			return nil
		}

		let lines = items
			.map { "- \($0)" }
			.joined(separator: "\n")

		return "\(title):\n\(lines)"
	}

	static func join(_ parts: [String?]) -> String {
		parts
			.compactMap(\.self)
			.joined(separator: "\n\n")
	}
}
