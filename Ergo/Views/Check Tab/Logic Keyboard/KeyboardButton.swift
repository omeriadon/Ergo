//
//  KeyboardButton.swift
//  Ergo
//
//  Created by Adon Omeri on 4/11/2026.
//

import SwiftUI

struct KeyboardButton: View {
	let entry: LogicKeyboardEntry

	@Binding var currentlySelectedLetter: String

	var alternateAction: ((String) -> Void)?
	let action: () -> Void

	@State private var isPressed = false
	@State private var showingAlternate = false

	private var alternate: LogicKeyboardEntry? {
		LogicKeyboardEntry.alternate(for: entry.glyph)
	}

	private var supportsAlternate: Bool {
		alternate != nil && alternateAction != nil
	}

	private var glassTint: Color {
		switch entry {
			case .variable:
				.white.opacity(0.1)
			case .symbol:
				.clear
			case .delimiter:
				.black.opacity(0.04)
		}
	}

	private var keyLabel: some View {
		Label(entry.glyph, systemImage: "character")
			.labelStyle(.titleOnly)
			.frame(height: 48)
			.frame(maxWidth: .infinity)
			.contentShape(RoundedRectangle(cornerRadius: 19))
	}

	private var glassKey: some View {
		keyLabel
			.glassEffect(
				.clear.tint(glassTint).interactive(),
				in: RoundedRectangle(cornerRadius: 19)
			)
			.background {
				RoundedRectangle(cornerRadius: 19)
					.fill(Color.accentColor.opacity(isPressed ? 1 : 0))
					.allowsHitTesting(false)
			}
	}

	var body: some View {
		glassKey
			.onTapGesture {
				action()
			}
			.onLongPressGesture(
				minimumDuration: supportsAlternate ? 0.5 : .infinity,
				maximumDistance: 10,
				perform: {
					guard let alternate, let alternateAction else {
						return
					}

					showingAlternate = true
					alternateAction(alternate.glyph)
				},
				onPressingChanged: { pressing in
					isPressed = pressing

					if pressing {
						currentlySelectedLetter = entry.glyph
					} else {
						showingAlternate = false

						if currentlySelectedLetter == entry.glyph {
							currentlySelectedLetter = ""
						}
					}
				}
			)
			.anchorPreference(
				key: AlternatePopupKey.self,
				value: .bounds
			) { anchor in
				guard showingAlternate, let alternate else {
					return []
				}

				return [
					AlternatePopupItem(
						glyph: alternate.glyph,
						bounds: anchor
					),
				]
			}
			.overlay(alignment: .bottomTrailing) {
				if alternate != nil {
					Circle()
						.fill(.secondary)
						.frame(width: 5, height: 5)
						.padding(7)
						.allowsHitTesting(false)
				}
			}
			.accessibilityElement(children: .ignore)
			.accessibilityLabel("Insert \(entry.glyph)")
			.accessibilityHint(
				alternate == nil
					? "Double tap to insert"
					: "Double tap to insert. Hold to insert \(alternate?.glyph ?? "")"
			)
			.accessibilityAddTraits(.isButton)
			.accessibilityIdentifier("check.logicKeyboard.\(entry.id)")
			.accessibilityAction {
				action()
			}
			.accessibilityAction(named: Text("Insert alternate")) {
				if let alternate {
					alternateAction?(alternate.glyph)
				}
			}
	}
}
