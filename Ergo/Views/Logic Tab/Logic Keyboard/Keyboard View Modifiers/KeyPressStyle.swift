//
//  KeyPressStyle.swift
//  Ergo
//
//  Created by Adon Omeri on 4/11/2026.
//

#if os(iOS)
	import SwiftUI

	struct KeyPressStyle: ButtonStyle {
		let tint: Color
		var onPressChange: ((Bool) -> Void)?

		func makeBody(configuration: Configuration) -> some View {
			configuration.label
				.glassEffect(
					.clear.tint(tint).interactive(),
					in: RoundedRectangle(cornerRadius: 19)
				)
				.background {
					RoundedRectangle(cornerRadius: 19)
						.fill(
							Color.accent.opacity(
								configuration.isPressed ? 1 : 0
							)
						)
						.allowsHitTesting(false)
						.animation(.easeInOut(duration: 0), value: configuration.isPressed)
				}
				.onChange(of: configuration.isPressed) { _, pressed in
					onPressChange?(pressed)
				}
		}
	}
#endif
