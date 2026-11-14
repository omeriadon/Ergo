//
//  LogicKeyboard.swift
//  Ergo
//
//  Created by Adon Omeri on 3/11/2026.
//

#if os(iOS)
	import Defaults
	import ErgoLogic
	import SwiftUI

	struct LogicKeyboard: View {
		let onInsert: (LogicKeyboardEntry) -> Void
		let onDelete: () -> Void
		let onDismiss: () -> Void
		let onEditLetters: () -> Void
		var descriptors = LogicLetters.emptyDescriptors

		@Default(.logicLetters) var logicLetters

		@State private var sync = ScrollSync()

		private var letters: [String] {
			LogicLetters.resolved(logicLetters)
		}

		var body: some View {
			VStack(spacing: 4) {
				HStack(spacing: 4) {
					ForEach(LogicLetters.slots, id: \.self) { slot in
						KeyboardButton(entry: .variable(slot), letters: letters, onInsert: onInsert)
							.accessibilityValue(LogicLetters.descriptor(for: slot, in: descriptors))
					}

					KeyboardButton2 {
						onEditLetters()
					} view: {
						Image(systemName: "pencil")
					}
					.accessibilityLabel("Edit letters")
					.accessibilityIdentifier("logic.logicKeyboard.editLetters")
				}

				HStack(spacing: 4) {
					ForEach(LogicKeyboardEntry.structuralRow, id: \.self) { entry in
						KeyboardButton(entry: entry, letters: letters, onInsert: onInsert)
					}
				}

				row1

				row2

				PageIndicator(sync: sync)
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
		}

		var row1: some View {
			HStack {
				pages(LogicKeyboardEntry.topRows, source: .top)

				KeyboardButton2 {
					onDelete()
				} view: {
					Image(systemName: "delete.left")
				}
				.accessibilityLabel("Delete previous entry")
				.accessibilityIdentifier("logic.logicKeyboard.delete")
				.frame(width: 58)
			}
		}

		var row2: some View {
			HStack {
				KeyboardButton(entry: .delimiter(","), letters: letters, onInsert: onInsert)
					.frame(width: 58)
					.zIndex(2)

				pages(LogicKeyboardEntry.bottomRows, source: .bottom)

				KeyboardButton2 {
					onInsert(.delimiter("\n"))
				} view: {
					Image(systemName: "return")
				}
				.accessibilityLabel("Insert newline")
				.accessibilityIdentifier("logic.logicKeyboard.newline")
				.frame(width: 58)
			}
		}

		private func pages(_ pages: [[LogicKeyboardEntry]], source: ScrollSync.Source) -> some View {
			ScrollView(.horizontal) {
				HStack(spacing: 0) {
					ForEach(pages, id: \.self) { page in
						HStack(spacing: 4) {
							ForEach(page, id: \.self) { entry in
								KeyboardButton(entry: entry, letters: letters, onInsert: onInsert)
							}
						}
						.containerRelativeFrame(.horizontal)
						.scrollTransition(.interactive) { content, phase in
							content
								.scaleEffect(phase.isIdentity ? 1 : 0.4)
								.blur(radius: phase.isIdentity ? 0 : 5)
						}
					}
				}
				.background {
					ScrollViewResolver { scroll in
						sync.register(scroll, for: source)
					}
				}
				.scrollTargetLayout()
			}
			.scrollIndicators(.hidden)
			.scrollTargetBehavior(.paging)
			.scrollClipDisabled()
			.onScrollGeometryChange(for: CGFloat.self) { geometry in
				ScrollSync.progress(of: geometry)
			} action: { _, progress in
				sync.scrolled(source, to: progress)
			}
			.onScrollPhaseChange { _, phase in
				sync.phaseChanged(source, to: phase)
			}
		}
	}

	/// Its own view so per-frame scroll progress only re-renders the dots, not every key
	private struct PageIndicator: View {
		let sync: ScrollSync

		var body: some View {
			HStack(spacing: 6) {
				ForEach(0 ..< 2) { index in
					Circle()
						.frame(width: 6, height: 6)
						.glassEffect(
							.regular
								.tint(.gray.opacity(
									index == 0
										? 1 - sync.progress * 0.9
										: 0 + sync.progress * 0.9
								))
								.interactive()
						)
				}
			}
		}
	}

	#Preview {
		LogicKeyboard(onInsert: { _ in
		}, onDelete: {}, onDismiss: {}, onEditLetters: {})
			.frame(height: 220)
			.background(.quinary)
	}
#endif
