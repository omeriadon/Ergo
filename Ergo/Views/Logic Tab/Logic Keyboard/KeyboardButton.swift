//
//  KeyboardButton.swift
//  Ergo
//
//  Created by Adon Omeri on 4/11/2026.
//

#if os(iOS)
	import ErgoLogic
	import SwiftUI

	struct KeyboardButton: View {
		let entry: LogicKeyboardEntry
		let letters: [String]
		let onInsert: (LogicKeyboardEntry) -> Void

		/// Drives the bubble, hides as soon as the finger lifts
		@State private var showingAlternate = false

		/// Decides what the release inserts, only cleared on the next press so the action always sees it
		@State private var alternateArmed = false

		@State private var holdTask: Task<Void, Never>?

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

		var body: some View {
			Button {
				if alternateArmed, let alternate = entry.alternate {
					onInsert(alternate)
				} else {
					onInsert(entry)
				}

				alternateArmed = false
			} label: {
				Text(entry.glyph(letters: letters))
					.frame(height: 48)
					.frame(maxWidth: .infinity)
					.contentShape(RoundedRectangle(cornerRadius: 19))
			}
			.buttonStyle(KeyPressStyle(tint: glassTint, onPressChange: pressHandler))
			.overlay(alignment: .bottomTrailing) {
				if entry.alternate != nil {
					Circle()
						.fill(.secondary)
						.frame(width: 5, height: 5)
						.padding(7)
						.allowsHitTesting(false)
				}
			}
			.overlay(alignment: .top) {
				alternateBubble
			}
			.animation(.snappy(duration: 0.18), value: showingAlternate)
			.sensoryFeedback(.selection, trigger: showingAlternate) { _, showing in
				showing
			}
			.accessibilityLabel("Insert \(entry.glyph(letters: letters))")
			.accessibilityHint(accessibilityHint)
			.accessibilityIdentifier("logic.logicKeyboard.\(entry.id)")
			.accessibilityAction(named: Text("Insert alternate")) {
				if let alternate = entry.alternate {
					onInsert(alternate)
				}
			}
		}

		@ViewBuilder
		private var alternateBubble: some View {
			if showingAlternate, let alternate = entry.alternate {
				unsafe Text(alternate.glyph(letters: letters))
					.font(.title2)
					.frame(width: 54, height: 54)
					.glassEffect(
						.regular.tint(.accent.opacity(0.5)),
						in: RoundedRectangle(cornerRadius: 18)
					)
					.offset(y: -58)
					.transition(.scale(scale: 0.6, anchor: .bottom).combined(with: .opacity))
					.allowsHitTesting(false)
			}
		}

		private var accessibilityHint: String {
			guard let alternate = entry.alternate else {
				return "Double tap to insert"
			}

			return "Double tap to insert. Hold to insert \(alternate.glyph(letters: letters))"
		}

		/// Only keys with an alternate need to know about holds
		private var pressHandler: ((Bool) -> Void)? {
			guard entry.alternate != nil else { return nil }
			return pressChanged
		}

		private func pressChanged(_ pressed: Bool) {
			holdTask?.cancel()

			if pressed {
				alternateArmed = false
				holdTask = Task {
					try? await Task.sleep(for: .milliseconds(400))
					guard !Task.isCancelled else { return }

					alternateArmed = true
					showingAlternate = true
				}
			} else {
				showingAlternate = false
			}
		}
	}

	struct KeyboardButton2<Content: View>: View {
		let action: () -> Void

		@ViewBuilder let view: () -> Content

		var body: some View {
			Button(action: action) {
				view()
					.frame(height: 48)
					.frame(maxWidth: .infinity)
					.contentShape(RoundedRectangle(cornerRadius: 19))
			}
			.buttonRepeatBehavior(.enabled)
			.buttonStyle(KeyPressStyle(tint: .black.opacity(0.3)))
		}
	}
#endif
