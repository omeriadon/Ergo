//
//  CustomViewMenuDemo.swift
//  Ergo
//
//  Created by Adon Omeri on 8/11/2026.
//

import SwiftUI

#if os(iOS)
	import UIKit

	struct CustomViewMenuDemo: View {
		@State private var value = 0.5

		var body: some View {
			VStack(alignment: .leading, spacing: 12) {
				Text("Menu Demo")
					.font(.headline)
				LabeledContent("Slider value", value: value, format: .percent)
					.accessibilityIdentifier("custom-menu-value")
				CustomViewMenu(
					title: "Adjust",
					systemImage: "slider.horizontal.3",
					width: 260,
					actions: [
						CustomMenuAction(
							title: "Reset",
							systemImage: "arrow.counterclockwise"
						) {
							value = 0.5
						},
					],
					header: {
						Label("Demo controls", systemImage: "slider.horizontal.3")
							.accessibilityIdentifier("custom-menu-header")
					},
					content: { dismiss in
						VStack(spacing: 12) {
							Slider(value: $value)
								.accessibilityLabel("Demo value")
								.accessibilityIdentifier("custom-menu-slider")
							Button(role: .cancel) {
								dismiss()
							} label: {
								Label("Close", systemImage: "xmark")
							}
							.accessibilityIdentifier("custom-menu-close")
						}
						.padding()
					}
				)
				.accessibilityIdentifier("custom-menu-adjust")
			}
		}
	}

	private struct CustomViewMenuDemoPreview: PreviewProvider {
		static var previews: some View {
			NavigationStack {
				List {
					CustomViewMenuDemo()
				}
				.navigationTitle("Custom View Menu")
			}
		}
	}
#endif
