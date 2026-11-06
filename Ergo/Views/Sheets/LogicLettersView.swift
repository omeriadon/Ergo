//
//  LogicLettersView.swift
//  Ergo
//
//  Created by Adon Omeri on 4/11/2026.
//

import Defaults
import ErgoLogic
import SwiftUI

struct LogicLettersView: View {
	/// The current board's, when opened from the editor. Settings only edits the letters, which every board shares.
	var descriptors: Binding<[String]>?

	@Default(.logicLetters) var logicLetters

	@State private var problem: LogicLetters.Problem?
	@FocusState private var focusedSlot: Int?

	private var letters: [String] {
		LogicLetters.resolved(logicLetters)
	}

	var body: some View {
		VStack {
			HStack(spacing: 8) {
				ForEach(LogicLetters.slots, id: \.self) { slot in
					LetterSlotField(
						letter: LogicLetters.letter(for: slot, in: letters),
						commit: { letter in
							setLetter(letter, in: slot)
						}
					)
					.focused($focusedSlot, equals: slot)
					.accessibilityLabel("Letter \(slot)")
				}
			}

			ZStack {
				switch problem {
					case .notALetter:
						Text("Only the letters A to Z.")
							.foregroundStyle(.red)
					case .alreadyUsed:
						Text("That letter's already one of the six.")
							.foregroundStyle(.red)
					case nil:
						Text("Six different letters for the logic keyboard. Anything you've already written switches over too.")
				}
			}
			.padding(.top, 8)
			.animation(.easeInOut(duration: 0.2), value: problem)
			.padding(.bottom, 30)

			if let descriptors {
				Section {
					ForEach(LogicLetters.slots, id: \.self) { slot in
						let letter = LogicLetters.letter(for: slot, in: letters)

						LabeledContent {
							DescriptorField(
								letter: letter,
								descriptor: LogicLetters.descriptor(for: slot, in: descriptors.wrappedValue),
								commit: { descriptor in
									setDescriptor(descriptor, in: slot)
								}
							)
						} label: {
							Text(letter)
								.monospaced()
						}
					}
				} header: {
					Text("On This Board")
				} footer: {
					Text("What each letter stands for here, up to \(LogicLetters.descriptorWordLimit) words. Translating English fills these in.")
				}
			}

			Button("Reset Letters", systemImage: "arrow.clockwise") {
				logicLetters = LogicLetters.defaults
				problem = nil
			}
			.buttonSizing(.flexible)
			.buttonStyle(.glass)
			.disabled(letters == LogicLetters.defaults)

			if let descriptors {
				Button("Clear Descriptors", role: .destructive) {
					descriptors.wrappedValue = LogicLetters.emptyDescriptors
				}
				.disabled(LogicLetters.slots.allSatisfy { LogicLetters.descriptor(for: $0, in: descriptors.wrappedValue).isEmpty })
			}

			Spacer()
		}
		.padding()
		.toolbarTitleVire("Logic Letters", "textformat.alt")
	}

	private func setLetter(_ letter: String, in slot: Int) -> Bool {
		problem = LogicLetters.problem(with: letter, in: slot, of: letters)
		guard problem == nil else { return false }

		var updated = letters
		updated[slot - LogicLetters.slots.lowerBound] = letter
		logicLetters = updated

		focusedSlot = slot < LogicLetters.slots.upperBound ? slot + 1 : nil
		return true
	}

	private func setDescriptor(_ descriptor: String, in slot: Int) {
		guard let descriptors else { return }
		var updated = LogicLetters.slots.map { LogicLetters.descriptor(for: $0, in: descriptors.wrappedValue) }
		updated[slot - LogicLetters.slots.lowerBound] = LogicLetters.sanitizedDescriptor(descriptor)
		descriptors.wrappedValue = updated
	}
}

/// The editor on its own, for when it's opened from the logic keyboard rather than Settings
struct LogicLettersSheet: View {
	@Environment(NavigationManager.self)
	private var navigation

	@Environment(BoardStore.self)
	private var boardStore

	var body: some View {
		@Bindable var boardStore = boardStore

		NavigationStack {
			LogicLettersView(descriptors: $boardStore.current.descriptors)
				.toolbar {
					ToolbarItem(placement: .topBarTrailing) {
						Button(role: .close) {
							navigation.dismissSheet()
						}
					}
				}
		}
	}
}

private struct LetterSlotField: View {
	let letter: String
	let commit: (String) -> Bool

	@State private var draft = ""

	var body: some View {
		TextField("", text: $draft)
			.multilineTextAlignment(.center)
			.textInputAutocapitalization(.characters)
			.autocorrectionDisabled()
			.font(.title2.monospaced())
			.fontDesign(.monospaced)
			.frame(height: 52)
			.glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 16))
			.onAppear {
				draft = letter
			}
			.onChange(of: letter) { _, letter in
				draft = letter.capitalized
			}
			.onChange(of: draft) { _, value in
				guard value != letter else { return }

				// Whatever was typed next to the old letter, so the slot never ends up empty or doubled
				guard let typed = value.last(where: { String($0) != letter }) else {
					draft = letter
					return
				}

				draft = commit(String(typed)) ? String(typed) : letter
			}
	}
}

private struct DescriptorField: View {
	let letter: String
	let descriptor: String
	let commit: (String) -> Void

	/// Kept apart from the stored descriptor so a trailing space survives while the next word is typed
	@State private var draft = ""

	var body: some View {
		TextField("What does \(letter) stand for?", text: $draft)
			.multilineTextAlignment(.trailing)
			.submitLabel(.done)
			.accessibilityLabel("Descriptor for \(letter)")
			.onAppear {
				draft = descriptor
			}
			.onChange(of: descriptor) { _, descriptor in
				guard LogicLetters.sanitizedDescriptor(draft) != descriptor else { return }
				draft = descriptor
			}
			.onChange(of: draft) { _, value in
				let limited = LogicLetters.limitedDescriptor(value)
				guard limited == value else {
					draft = limited
					return
				}

				commit(value)
			}
			.onSubmit {
				draft = descriptor
			}
	}
}

#Preview {
	NavigationStack {
		LogicLettersView()
	}
}
