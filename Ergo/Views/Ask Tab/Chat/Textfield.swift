//
//  Textfield.swift
//  Ergo
//
//  Created by Adon Omeri on 7/11/2026.
//

import SwiftUI

struct AskComposer: View {
	@Binding var text: String
	var isFocused: FocusState<Bool>.Binding
	let hasAttachments: Bool
	let isRunning: Bool
	let sent: Int
	var fitsSheet = false
	let send: () -> Void
	let stop: () -> Void

	/// The same on the sides and the bottom, or the corners can't share a centre with the sheet's
	static let sheetInset: CGFloat = 16

	private var canSend: Bool {
		hasAttachments || !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
	}

	private var field: some View {
		TextField("Ask anything", text: $text, axis: .vertical)
			.lineLimit(1 ... 6)
			.focused(isFocused)
			.padding(.horizontal, 16)
			.padding(.vertical, 11)
	}

	/// Not one `AnyShape`, which could hide from the glass that it follows its container
	@ViewBuilder
	private var glassField: some View {
		if fitsSheet {
			field.glassEffect(.regular.interactive(), in: ConcentricRectangle(corners: .concentric(minimum: .fixed(22))))
		} else {
			field.glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 22))
		}
	}

	var body: some View {
		GlassEffectContainer(spacing: 1) {
			HStack(alignment: .bottom, spacing: 8) {
				glassField
					.accessibilityIdentifier("ask.composer")

				if isRunning {
					Button("Stop", systemImage: "stop.fill", action: stop)
						.font(.body.scaled(by: 0.8))
						.labelStyle(.iconOnly)
						.buttonStyle(.glass)
						.buttonBorderShape(.circle)
						.controlSize(.large)
						.accessibilityIdentifier("ask.stop")
				} else {
					Button("Send", systemImage: "arrow.up", action: send)
						.font(.body.scaled(by: 0.8))
						.labelStyle(.iconOnly)
						.symbolEffect(.bounce.up, value: sent)
						.buttonStyle(.glassProminent)
						.buttonBorderShape(.circle)
						.controlSize(.large)
						.disabled(!canSend)
						.accessibilityIdentifier("ask.send")
				}
			}
			.padding(.horizontal, fitsSheet ? Self.sheetInset : 22)
			.padding(.top, 10)
			.padding(.bottom, fitsSheet ? Self.sheetInset : 10)
			.animation(.smooth, value: isRunning)
		}
	}
}
