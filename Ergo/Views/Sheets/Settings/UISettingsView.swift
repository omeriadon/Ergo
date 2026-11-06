//
//  UISettingsView.swift
//  Ergo
//
//  Created by Adon Omeri on 5/11/2026.
//

import Defaults
import ErgoLogic
import SwiftUI

struct UISettingsView: View {
	@Default(.ditherEnabled) var ditherEnabled
	@Default(.hapticsEnabled) var hapticsEnabled
	@Default(.logicLetters) var logicLetters

	var body: some View {
		List {
			Section {
				Toggle("Background Effects", systemImage: "rectangle.badge.sparkles", isOn: $ditherEnabled)
			} footer: {
				Text("The animated backgrounds behind detail pages and Check. Turning this off removes them entirely.")
			}

			Section {
				Toggle("Haptics", systemImage: "hand.tap", isOn: $hapticsEnabled)
			} footer: {
				Text("A tap as you drag a box or arrow across the canvas grid, and a stronger one when an arrow reaches a box.")
			}

			Section {
				NavigationLink {
					LogicLettersView()
				} label: {
					LabeledContent {
						Text(LogicLetters.resolved(logicLetters).joined(separator: " "))
							.monospaced()
					} label: {
						Label("Logic Letters", systemImage: "textformat.alt")
					}
				}
			}
		}
		.toolbarTitleVire("UI", "widget.small")
	}
}
