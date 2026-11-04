//
//  KeyGlassModifier.swift
//  Ergo
//
//  Created by Adon Omeri on 4/11/2026.
//

import SwiftUI

struct KeyGlassModifier: ViewModifier {
	let isPressed: Bool
	let tint: Color

	func body(content: Content) -> some View {
		content
			.background {
				RoundedRectangle(cornerRadius: 19)
					.fill(Color.accentColor.opacity(isPressed ? 1 : 0))
					.allowsHitTesting(false)
			}
			.glassEffect(
				.clear.tint(tint),
				in: RoundedRectangle(cornerRadius: 19)
			)
			.scaleEffect(isPressed ? 0.93 : 1)
			.animation(
				.spring(duration: 0.25, bounce: 0.4),
				value: isPressed
			)
	}
}

struct LetterPressStyle: ButtonStyle {
	let letter: String
	let entry: LogicKeyboardEntry
	@Binding var selectedLetter: String

	func makeBody(configuration: Configuration) -> some View {
		configuration.label
			.modifier(
				KeyGlassModifier(
					isPressed: configuration.isPressed,
					tint: glassTint
				)
			)
			.onChange(of: configuration.isPressed) { _, pressed in
				if pressed {
					selectedLetter = letter
				} else if selectedLetter == letter {
					selectedLetter = ""
				}
			}
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
}

private struct LetterPressStyle2: ButtonStyle {
	func makeBody(configuration: Configuration) -> some View {
		configuration.label
			.modifier(
				KeyGlassModifier(
					isPressed: configuration.isPressed,
					tint: .black.opacity(0.3)
				)
			)
	}
}
