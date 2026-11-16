//
//  NewBeliefSheet.swift
//  Ergo
//
//  Created by Adon Omeri on 16/11/2026.
//

import Defaults
import ErgoCatalog
import SwiftUI

/// Writing a belief of the person's own: one claim, and how sure. `LibrarySheet.newBelief`.
struct NewBeliefSheet: View {
	@Environment(NavigationManager.self)
	private var navigation

	@Default(.beliefs) private var ledger

	@State private var statement = ""
	@State private var value = Double(BeliefScale.middle)

	@FocusState private var isFocused: Bool

	private var canAdd: Bool {
		!statement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
	}

	var body: some View {
		NavigationStack {
			Form {
				Section {
					TextField("Something you believe", text: $statement, axis: .vertical)
						.lineLimit(2 ... 6)
						.focused($isFocused)
						.accessibilityIdentifier("newBelief.statement")
				} footer: {
					Text("One claim, as you'd say it. \"We have free will\", not \"Do we have free will?\"")
				}

				Section("How Sure") {
					BeliefSlider(value: $value, color: .accentColor)
				}
			}
			.formStyle(.grouped)
			.navigationTitle("New Belief")
			.toolbarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .sheetDismissal) {
					Button(role: .cancel) {
						navigation.dismissSheet()
					}
					.keyboardShortcut(.cancelAction)
					.accessibilityIdentifier("newBelief.cancel")
				}

				ToolbarItem(placement: .sheetConfirmation) {
					Button("Add", role: .confirm) {
						ledger.add(statement, confidence: BeliefScale.snapped(value))
						navigation.dismissSheet()
					}
					.disabled(!canAdd)
					.keyboardShortcut(.defaultAction)
					.accessibilityIdentifier("newBelief.add")
				}
			}
			.onAppear {
				isFocused = true
			}
		}
		.presentationDetents([.medium, .large])
	}
}
