//
//  View+.swift
//  Ergo
//
//  Created by Adon Omeri on 2/11/2026.
//

import SwiftUI

extension View {
	@ViewBuilder
	func conditionalButtonStyle(_ prominent: Bool) -> some View {
		if prominent {
			buttonStyle(.glassProminent)
		} else {
			buttonStyle(.automatic)
		}
	}
}
