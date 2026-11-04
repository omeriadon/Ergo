//
//  LogicKeyboard.swift
//  Ergo
//
//  Created by Adon Omeri on 3/11/2026.
//

import Defaults
import SwiftUI

struct LogicKeyboard: View {
	let onInsert: (String) -> Void
	let onDelete: () -> Void
	let onDismiss: () -> Void

	@Default(.logicLetters) var logicLetters

	@State private var currentlySelectedLetter = ""

	enum Source {
		case top, bottom
	}

	struct Metrics: Equatable {
		var progress: CGFloat = 0
		var distance: CGFloat = 0

		init() {}

		init(_ geometry: ScrollGeometry) {
			distance = max(
				0,
				geometry.contentSize.width - geometry.containerSize.width
			)

			progress = distance > 0
				? min(max(geometry.contentOffset.x / distance, 0), 1)
				: 0
		}
	}

	@State private var sync = ScrollSync()
	@State private var source: Source?

	@State private var pageProgress: CGFloat = 0

	private var pageIndicator: some View {
		HStack(spacing: 6) {
			ForEach(0 ..< 2) { index in
				Circle()
					.frame(width: 6, height: 6)
					.glassEffect(
						.regular
							.tint(.gray.opacity(
								index == 0
									? 1 - pageProgress * 0.9
									: 0 + pageProgress * 0.9
							))
							.interactive()
					)
			}
		}
	}

	var body: some View {
		VStack(spacing: 4) {
			HStack(spacing: 4) {
				ForEach(LogicKeyboardEntry.configuredLetters(logicLetters), id: \.self) { entry in
					KeyboardButton(entry: entry, currentlySelectedLetter: $currentlySelectedLetter) {
						onInsert(entry.glyph)
					}
				}

				KeyboardButton2(currentlySelectedLetter: $currentlySelectedLetter) {
					// trigger symbol sheet
				} view: {
					Image(systemName: "pencil")
				}
				.accessibilityLabel("Open symbol keyboard")
				.accessibilityIdentifier("check.logicKeyboard.symbols")
			}

			HStack(spacing: 4) {
				ForEach(LogicKeyboardEntry.structuralRow, id: \.self) { entry in
					KeyboardButton(entry: entry, currentlySelectedLetter: $currentlySelectedLetter) {
						onInsert(entry.glyph)
					}
				}
			}

			row1

			row2

			pageIndicator
				.padding(.top, 3)
		}
		.padding(.horizontal, 10)
		.padding(.top, 10)
		.font(.title3)
		.fontDesign(.monospaced)
		.monospaced()
		.frame(
			maxWidth: .infinity,
			maxHeight: .infinity,
			alignment: .top
		)
		.dynamicTypeSize(.small)
		.overlayPreferenceValue(AlternatePopupKey.self) { items in
			GeometryReader { proxy in
				ForEach(items, id: \.glyph) { item in
					let frame = proxy[item.bounds]

					Text(item.glyph)
						.font(.title2)
						.fontDesign(.monospaced)
						.frame(width: 54, height: 54)
						.glassEffect(.regular.tint(.accent.opacity(0.5)).interactive(), in: RoundedRectangle(cornerRadius: 18))
						.position(
							x: frame.midX,
							y: frame.minY - 34
						)
						.transition(
							.blurReplace
						)
				}
			}
			.allowsHitTesting(false)
			.animation(.easeOut(duration: 0.15), value: items.count)
		}
	}

	var row1: some View {
		HStack {
			ScrollView(.horizontal) {
				HStack(spacing: 0) {
					ForEach(LogicKeyboardEntry.topRows, id: \.self) { array in
						HStack(spacing: 4) {
							ForEach(array, id: \.self) { letter in
								KeyboardButton(
									entry: letter,
									currentlySelectedLetter: $currentlySelectedLetter,
									alternateAction: onInsert
								) {
									onInsert(letter.glyph)
								}
							}
						}
						.containerRelativeFrame(.horizontal)
						.scrollTransition(.interactive) { content, phase in
							content
								.scaleEffect(phase.isIdentity ? 1 : 0.5)
								.blur(radius: phase.isIdentity ? 0 : 5)
						}
					}
				}
				.background {
					ScrollViewResolver { scroll in
						sync.top = scroll
					}
				}
				.scrollTargetLayout()
			}
			.scrollIndicators(.hidden)
			.scrollTargetBehavior(.paging)
			.scrollClipDisabled()
			.onScrollGeometryChange(for: Metrics.self) {
				Metrics($0)
			} action: { _, metrics in
				if source == .top {
					pageProgress = metrics.progress
					sync.moveBottom(to: metrics.progress)
				}
			}
			.onScrollPhaseChange { _, phase in
				if phase == .interacting {
					source = .top
				} else if phase == .idle, source == .top {
					source = nil
				}
			}

			KeyboardButton2(currentlySelectedLetter: $currentlySelectedLetter) {
				onDelete()
			} view: {
				Image(systemName: "delete.left")
			}
			.accessibilityLabel("Delete previous entry")
			.accessibilityIdentifier("check.logicKeyboard.delete")
			.frame(width: 58)
		}
	}

	var row2: some View {
		HStack {
			KeyboardButton(entry: .delimiter(","), currentlySelectedLetter: $currentlySelectedLetter) { onInsert(",") }
				.frame(width: 58)
				.zIndex(2)

			ScrollView(.horizontal) {
				HStack(spacing: 0) {
					ForEach(LogicKeyboardEntry.bottomRows, id: \.self) { array in
						HStack(spacing: 4) {
							ForEach(array, id: \.self) { letter in
								KeyboardButton(entry: letter, currentlySelectedLetter: $currentlySelectedLetter) { onInsert(letter.glyph) }
							}
						}
						.containerRelativeFrame(.horizontal)
						.scrollTransition(.interactive) { content, phase in
							content
								.scaleEffect(phase.isIdentity ? 1 : 0.5)
								.blur(radius: phase.isIdentity ? 0 : 5)
						}
					}
				}
				.background {
					ScrollViewResolver { scroll in
						sync.bottom = scroll
					}
				}
				.scrollTargetLayout()
			}
			.scrollIndicators(.hidden)
			.scrollClipDisabled()
			.scrollBounceBehavior(.basedOnSize)
			.scrollTargetBehavior(.paging)
			.onScrollGeometryChange(for: Metrics.self) {
				Metrics($0)
			} action: { _, metrics in
				if source == .bottom {
					pageProgress = metrics.progress
					sync.moveTop(to: metrics.progress)
				}
			}
			.onScrollPhaseChange { _, phase in
				if phase == .interacting {
					source = .bottom
				} else if phase == .idle, source == .bottom {
					source = nil
				}
			}

			KeyboardButton2(currentlySelectedLetter: $currentlySelectedLetter) {
				onInsert("\n")
			} view: {
				Image(systemName: "return")
			}
			.accessibilityLabel("Insert newline")
			.accessibilityIdentifier("check.logicKeyboard.newline")
			.frame(width: 58)
		}
	}
}

struct AlternatePopupItem {
	let glyph: String
	let bounds: Anchor<CGRect>
}

struct AlternatePopupKey: PreferenceKey {
	static let defaultValue: [AlternatePopupItem] = []

	static func reduce(
		value: inout [AlternatePopupItem],
		nextValue: () -> [AlternatePopupItem]
	) {
		value.append(contentsOf: nextValue())
	}
}

struct KeyboardButton2<Content: View>: View {
	@Binding var currentlySelectedLetter: String
	let action: () -> Void

	@ViewBuilder let view: () -> Content

	var body: some View {
		Button(action: action) {
			view()
				.frame(height: 48)
				.frame(maxWidth: .infinity)
		}
		.buttonRepeatBehavior(.enabled)
		.buttonStyle(LetterPressStyle2())
	}
}

// struct LetterPressStyle: ButtonStyle {
//	let letter: String
//	let entry: LogicKeyboardEntry
//	@Binding var selectedLetter: String
//
//	func makeBody(configuration: Configuration) -> some View {
//		configuration.label
//			.glassEffect(
//				.clear.tint(glassTint).interactive(),
//				in: RoundedRectangle(cornerRadius: 19)
//			)
//			.background {
//				RoundedRectangle(cornerRadius: 19)
//					.fill(
//						Color.accentColor.opacity(
//							configuration.isPressed ? 1 : 0
//						)
//					)
//					.allowsHitTesting(false)
//					.animation(.easeInOut(duration: 0), value: configuration.isPressed)
//			}
//			.onChange(of: configuration.isPressed) { _, pressed in
//				if pressed {
//					selectedLetter = letter
//				} else if selectedLetter == letter {
//					selectedLetter = ""
//				}
//			}
//	}
//
//	private var glassTint: Color {
//		switch entry {
//			case .variable:
//				.white.opacity(0.1)
//			case .symbol:
//				.clear
//			case .delimiter:
//				.black.opacity(0.04)
//		}
//	}
// }

private struct LetterPressStyle2: ButtonStyle {
	func makeBody(configuration: Configuration) -> some View {
		configuration.label
			.glassEffect(
				.clear.tint(.black.opacity(0.3)).interactive(),
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
					.animation(.easeInOut(duration: 0), value: configuration.isPressed)
			}
	}
}

#Preview {
	LogicKeyboard(onInsert: { _ in
	}, onDelete: {}, onDismiss: {}, logicLetters: .init(.logicLetters))
		.frame(height: 220)
		.background(.quinary)
}
