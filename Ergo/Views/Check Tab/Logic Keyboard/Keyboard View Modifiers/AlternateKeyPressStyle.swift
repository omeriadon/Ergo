//
//  AlternateKeyPressStyle.swift
//  Ergo
//
//  Created by Adon Omeri on 4/11/2026.
//

import SwiftUI

struct AlternateKeyPressStyle: PrimitiveButtonStyle {
	@Binding var showingAlternate: Bool
	let insertAlternate: () -> Void
	@GestureState private var isHolding = false

	func makeBody(configuration: Configuration) -> some View {
		configuration.label
			.glassEffect(.clear.interactive(), in: RoundedRectangle(cornerRadius: 19))
			.background {
				RoundedRectangle(cornerRadius: 19)
					.fill(Color.accentColor.opacity(isHolding ? 1 : 0))
					.allowsHitTesting(false)
			}
			.gesture(
				LongPressGesture(minimumDuration: 0.5, maximumDistance: 10)
					.exclusively(before: TapGesture())
					.updating($isHolding) { value, state, _ in
						if case .first(true) = value {
							state = true
						}
					}
					.onEnded { value in
						switch value {
							case .first(true):
								insertAlternate()
							case .second:
								configuration.trigger()
							default:
								break
						}
					}
			)
			.onChange(of: isHolding) { _, value in
				showingAlternate = value
			}
			.accessibilityAction {
				configuration.trigger()
			}
	}
}
