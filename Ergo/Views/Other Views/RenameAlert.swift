//
//  RenameAlert.swift
//  Ergo
//
//  Created by Adon Omeri on 7/11/2026.
//

import SwiftUI

/// A name being typed for the thing with this id
struct Renaming<ID: Hashable> {
	let id: ID
	var name: String
}

extension String {
	/// Nil when there's nothing but white space
	var trimmedNonEmpty: String? {
		let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
		return trimmed.isEmpty ? nil : trimmed
	}
}

extension View {
	/// Asks for a name. Leaving it empty is allowed: the name is then taken from what's written.
	func renameAlert<ID: Hashable>(
		_ title: LocalizedStringKey,
		renaming: Binding<Renaming<ID>?>,
		perform: @escaping (ID, String) -> Void
	) -> some View {
		alert(
			title,
			isPresented: Binding(
				get: { renaming.wrappedValue != nil },
				set: { isShown in
					if !isShown {
						renaming.wrappedValue = nil
					}
				}
			)
		) {
			TextField("Name", text: Binding(
				get: { renaming.wrappedValue?.name ?? "" },
				set: { renaming.wrappedValue?.name = $0 }
			))
			.accessibilityIdentifier("rename.name")

			Button("Rename") {
				if let current = renaming.wrappedValue {
					perform(current.id, current.name)
				}
			}

			Button("Cancel", role: .cancel) {}
		} message: {
			Text("Leave it empty to use the first line")
		}
	}
}
