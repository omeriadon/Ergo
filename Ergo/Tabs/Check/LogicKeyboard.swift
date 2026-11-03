//
//  LogicKeyboard.swift
//  Ergo
//
//  Created by Adon Omeri on 3/11/2026.
//

import SwiftUI

struct LogicKeyboard: View {
	let onInsert: (String) -> Void
	let onDelete: () -> Void
	let onDismiss: () -> Void

	private let letters = ["X", "Y", "Z", "P", "Q", "R"]

	var body: some View {
		VStack(spacing: 12) {
			ScrollView(.horizontal) {
				HStack(spacing: 0) {
					page(letters)
					page(SymbolEnum.basic.map(\.glyph))
					page(SymbolEnum.predicate.map(\.glyph))
				}
				.scrollTargetLayout()
			}
			.scrollTargetBehavior(.paging)
			.scrollIndicators(.hidden)
			.frame(height: 52)

			HStack(spacing: 8) {
				Button("(") { onInsert("(") }
				Button(")") { onInsert(")") }
				Button("[") { onInsert("[") }
				Button("]") { onInsert("]") }
			}
			.frame(height: 46)

			HStack(spacing: 8) {
				Button("Space") {
					onInsert(" ")
				}

				Button {
					onDelete()
				} label: {
					Image(systemName: "delete.left")
				}

				Button("Return") {
					onInsert("\n")
				}

				Button("Done") {
					onDismiss()
				}
			}
			.frame(height: 46)
		}
		.buttonStyle(.glass)
		.padding(12)
		.frame(
			maxWidth: .infinity,
			maxHeight: .infinity,
			alignment: .top
		)
	}

	private func page(_ symbols: [String]) -> some View {
		HStack(spacing: 6) {
			ForEach(symbols, id: \.self) { symbol in
				Button {
					onInsert(symbol)
				} label: {
					Text(symbol)
						.font(.system(.title2, design: .monospaced))
						.frame(maxWidth: .infinity)
						.frame(height: 44)
				}
			}
		}
		.padding(.horizontal, 8)
		.containerRelativeFrame(.horizontal)
	}
}
