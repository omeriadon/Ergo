//
//  CustomViewMenuButton.swift
//  Ergo
//
//  Created by Adon Omeri on 8/11/2026.
//

import SwiftUI

#if os(iOS)
	import UIKit

	struct CustomViewMenuButton<Content: View, Header: View>: UIViewRepresentable {
		let title: String
		let systemImage: String
		let width: CGFloat
		let content: (@escaping () -> Void) -> Content
		let header: (() -> Header)?
		let actions: [CustomMenuAction]
		let onSelect: (() -> Void)?

		func makeCoordinator() -> Coordinator {
			Coordinator(self)
		}

		func makeUIView(context _: Context) -> UIButton {
			let button = UIButton(type: .system)
			button.accessibilityLabel = title
			button.accessibilityIdentifier = "custom-view-menu-\(title)"
			button.showsMenuAsPrimaryAction = true
			return button
		}

		func updateUIView(_ button: UIButton, context: Context) {
			context.coordinator.parent = self
			var configuration = UIButton.Configuration.plain()
			configuration.title = title
			configuration.image = UIImage(systemName: systemImage)
			configuration.imagePadding = 6
			button.configuration = configuration
			button.accessibilityLabel = title
			button.accessibilityIdentifier = "custom-view-menu-\(title)"
			button.menu = context.coordinator.makeMenu(for: button)
		}

		func sizeThatFits(_: ProposedViewSize, uiView: UIButton, context _: Context) -> CGSize? {
			uiView.intrinsicContentSize
		}

		static func dismantleUIView(_ button: UIButton, coordinator: Coordinator) {
			coordinator.dismissMenu()
			button.menu = nil
		}
	}
#endif
