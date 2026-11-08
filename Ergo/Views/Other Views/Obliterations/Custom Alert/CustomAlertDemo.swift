//
//  CustomAlertDemo.swift
//  Ergo
//
//  Created by Adon Omeri on 8/11/2026.
//

import SwiftUI

#if os(iOS)
	import UIKit

	struct CustomAlertDemo: View {
		@State private var isPresented = false
		@State private var value = 0.5

		var body: some View {
			VStack(alignment: .leading, spacing: 12) {
				Text("Alert Demo")
					.font(.headline)
				LabeledContent("Slider value", value: value, format: .percent)
					.accessibilityIdentifier("custom-alert-value")
				Button {
					isPresented = true
				} label: {
					Label("Open custom alert", systemImage: "rectangle.portrait.and.arrow.right")
				}
				.accessibilityLabel("Open custom alert")
				.accessibilityIdentifier("custom-alert-open")
			}
			.customAlert(
				title: "Adjust value",
				message: "Choose a value for this demo.",
				isPresented: $isPresented,
				contentHeight: 112,
				headerPlacement: .aboveTitle,
				header: {
					Image(systemName: "person.crop.circle.fill")
						.font(.title)
						.accessibilityLabel("Account avatar")
						.accessibilityIdentifier("custom-alert-header-avatar")
				},
				content: { dismiss in
					VStack(spacing: 12) {
						Slider(value: $value)
							.accessibilityLabel("Demo value")
							.accessibilityIdentifier("custom-alert-slider")
						Button(role: .cancel) {
							dismiss()
						} label: {
							Label("Close", systemImage: "xmark")
						}
						.accessibilityIdentifier("custom-alert-close")
					}
				},
				actions: [
					CustomAlertAction(title: "Cancel", role: .cancel),
				]
			)
		}
	}

	private struct CustomAlertDemoPreview: PreviewProvider {
		static var previews: some View {
			NavigationStack {
				List {
					CustomAlertDemo()
				}
				.navigationTitle("Custom Alert")
			}
		}
	}
#endif
