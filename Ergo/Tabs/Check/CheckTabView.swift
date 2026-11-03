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
}
