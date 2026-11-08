//
//  CustomMenuAction.swift
//  Ergo
//
//  Created by Adon Omeri on 3/11/2026.
//

// CustomViewMenu.swift
//
// Usage:
// Embed CustomViewMenuDemo() inside an existing NavigationStack. Do not nest NavigationStacks.
// Standalone use: NavigationStack { CustomViewMenuDemo() } or open its Xcode preview.
// CustomViewMenu(title: "Sort", systemImage: "arrow.up.arrow.down") { dismiss in
//     Button { dismiss() } label: { Label("Newest", systemImage: "clock") }
//         .accessibilityIdentifier("sort-newest")
// }
//
// This uses the private UICustomViewMenuElement API when available. Private APIs
// can change or be rejected by App Review. Environment objects and custom
// environment values do not cross the independent hosting boundary; inject them.

import SwiftUI

#if os(iOS)
	import UIKit

	public struct CustomMenuAction {
		public let title: String
		public let systemImage: String
		public let isDestructive: Bool
		public let handler: () -> Void

		public init(
			title: String,
			systemImage: String,
			isDestructive: Bool = false,
			handler: @escaping () -> Void
		) {
			self.title = title
			self.systemImage = systemImage
			self.isDestructive = isDestructive
			self.handler = handler
		}
	}

	public struct CustomViewMenu<Content: View, Header: View>: View {
		private let title: String
		private let systemImage: String
		private let width: CGFloat
		private let content: (@escaping () -> Void) -> Content
		private let header: (() -> Header)?
		private let actions: [CustomMenuAction]
		private let onSelect: (() -> Void)?

		public init(
			title: String,
			systemImage: String,
			width: CGFloat = 260,
			onSelect: (() -> Void)? = nil,
			actions: [CustomMenuAction] = [],
			@ViewBuilder content: @escaping (@escaping () -> Void) -> Content
		) where Header == EmptyView {
			self.title = title
			self.systemImage = systemImage
			self.width = width
			self.content = content
			header = nil
			self.actions = actions
			self.onSelect = onSelect
		}

		public init(
			title: String,
			systemImage: String,
			width: CGFloat = 260,
			onSelect: (() -> Void)? = nil,
			actions: [CustomMenuAction] = [],
			@ViewBuilder header: @escaping () -> Header,
			@ViewBuilder content: @escaping (@escaping () -> Void) -> Content
		) {
			self.title = title
			self.systemImage = systemImage
			self.width = width
			self.content = content
			self.header = header
			self.actions = actions
			self.onSelect = onSelect
		}

		public var body: some View {
			CustomViewMenuButton(
				title: title,
				systemImage: systemImage,
				width: width,
				content: content,
				header: header,
				actions: actions,
				onSelect: onSelect
			)
			.fixedSize()
		}
	}
#endif
