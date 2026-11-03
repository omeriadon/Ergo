//
//  CheckTabView.swift
//  Ergo
//
//  Created by Adon Omeri on 1/11/2026.
//

import SwiftUI

struct CheckTabView: View {
	enum Field: Hashable {
		case english, logic
	}

	@Environment(NavigationManager.self)
	private var navigation

	@State private var english = ""
	@State private var englishSelection: TextSelection?
	@FocusState private var englishFocused: Bool

	@State private var logic = ""

	@State private var focusedField: Field?

	private var logicFocus: Binding<Bool> {
		Binding(
			get: {
				focusedField == .logic
			},
			set: { focused in
				if focused {
					focusedField = .logic
				} else if focusedField == .logic {
					focusedField = nil
				}
			}
		)
	}

	@State private var ditherSize = CGSize.zero

	var body: some View {
		ZStack {
			VStack(spacing: 20) {
				TextEditor(text: $english, selection: $englishSelection)
					.textEditorStyle(.plain)
					.focused($englishFocused)
					.padding(15)
					.glassEffect(
						.regular.interactive(),
						in: RoundedRectangle(cornerRadius: 20)
					)
					.accessibilityLabel("English editor")
					.accessibilityIdentifier("check.englishEditor")
					.onChange(of: englishFocused) { _, focused in
						if focused {
							focusedField = .english
						} else if focusedField == .english {
							focusedField = nil
						}
					}

				LogicTextEditor(
					text: $logic,
					isFocused: logicFocus
				)
				.padding(15)
				.glassEffect(
					.regular.interactive(),
					in: RoundedRectangle(cornerRadius: 20)
				)

//				bottomControls
			}
			.padding(15)
			.frame(maxWidth: .infinity, maxHeight: .infinity)
			.background(alignment: .top) {
				DitherView(configuration: detailViewConf)
					.frame(
						width: ditherSize.width,
						height: ditherSize.height
					)
					.ignoresSafeArea(.container)
					.allowsHitTesting(false)
					.onGeometryChange(for: CGSize.self, of: { $0.size }) { _, size in
						print("Actual dither size:", size)
					}
			}
			.onGeometryChange(for: CGSize.self, of: { $0.size }) { _, size in
				guard size.width > 0, size.height > 0 else { return }

				if size.width == ditherSize.width {
					// Never shrink the background during keyboard presentation
					ditherSize.height = max(ditherSize.height, size.height)
				} else if focusedField == nil {
					ditherSize = size
				}
			}
		}
		.toolbar {
			ToolbarItem(placement: .topBarTrailing) {
				if focusedField != nil {
					Button(role: .confirm) {
						englishFocused = false
						focusedField = nil
					} label: {
						Label("Done", systemImage: "checkmark")
					}
					.buttonStyle(.glassProminent)
					.accessibilityLabel("Done")
					.accessibilityIdentifier("check.doneButton")
				}
			}
		}
	}

	@ViewBuilder
	var bottomControls: some View {
		if focusedField == nil {
			GeometryReader { geo in
				ScrollView(.horizontal) {
					HStack(spacing: 0) {
						LetterPage(height: geo.size.height)

						HStack {
							ForEach(SymbolEnum.basic) { symbol in
								Text(symbol.glyph)
							}
						}
						.containerRelativeFrame(.horizontal)

						HStack {
							ForEach(SymbolEnum.predicate) { symbol in
								Text(symbol.glyph)
							}
						}
						.containerRelativeFrame(.horizontal)

						HStack {
							Text("Custom")
							Button("Example") {}
						}
						.containerRelativeFrame(.horizontal)
					}
					.scrollTargetLayout()
				}
				.scrollClipDisabled()
				.scrollTargetBehavior(.paging)
				.scrollBounceBehavior(.always)
				.scrollIndicators(.hidden)
			}
			.frame(height: 40)
			.font(.system(.title2, design: .monospaced))
			.monospaced()
			.padding(.horizontal, 5)
			.padding(.vertical, 5)
			.glassEffect(.clear.interactive(), in: Capsule())
		}
	}
}

private struct LetterPage: View {
	let height: CGFloat

	private let letters: [String] = [
		"X", "Y", "Z", "P", "Q", "R",
	]

	@State private var currentlySelectedLetter = ""

	var body: some View {
		HStack(spacing: 0) {
			ForEach(letters, id: \.self) { letter in
				Button {} label: {
					Text(letter)
						.frame(width: height, height: height)
				}
				.buttonStyle(
					LetterPressStyle(
						letter: letter,
						selectedLetter: $currentlySelectedLetter
					)
				)
				.scrollTransition(.interactive) { content, phase in
					content
						.scaleEffect(phase.isIdentity ? 1 : 0)
						.blur(radius: phase.isIdentity ? 0 : 10)
				}

				if letter != letters.last {
					Spacer(minLength: 1)
				}
			}

			Spacer()

			Button {} label: {
				Label("Edit Symbols", systemImage: "pencil")
					.labelStyle(.iconOnly)
			}
			.frame(width: height, height: height)
			.scrollTransition(.interactive) { content, phase in
				content
					.scaleEffect(phase.isIdentity ? 1 : 0)
					.blur(radius: phase.isIdentity ? 0 : 10)
			}
		}
		.scrollTransition(.interactive) { content, phase in
			content
				.scaleEffect(phase.isIdentity ? 1 : 0.7)
		}
		.containerRelativeFrame(.horizontal)
	}
}

private struct LetterPressStyle: ButtonStyle {
	let letter: String
	@Binding var selectedLetter: String

	func makeBody(configuration: Configuration) -> some View {
		configuration.label
			.glassEffect(
				.clear.interactive(),
				in: RoundedRectangle(cornerRadius: 19)
			)
			.background {
				RoundedRectangle(cornerRadius: 19)
					.fill(
						Color.accentColor.opacity(
							configuration.isPressed ? 1 : 0
						)
					)
					.allowsHitTesting(false)
					.animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
			}
			.onChange(of: configuration.isPressed) { _, pressed in
				if pressed {
					selectedLetter = letter
				} else if selectedLetter == letter {
					selectedLetter = ""
				}
			}
	}
}
