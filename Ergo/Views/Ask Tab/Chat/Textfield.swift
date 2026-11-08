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
	let send: () -> Void
	let stop: () -> Void

	private var canSend: Bool {
		hasAttachments || !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
	}

	var body: some View {
		GlassEffectContainer(spacing: 1) {
			HStack(alignment: .bottom, spacing: 8) {
				TextField("Ask anything", text: $text, axis: .vertical)
					.lineLimit(1 ... 6)
					.focused(isFocused)
					.padding(.horizontal, 16)
					.padding(.vertical, 11)
					.glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 22))
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
			.padding(.horizontal, 22)
			.padding(.vertical, 10)
			.animation(.smooth, value: isRunning)
		}
	}
}
