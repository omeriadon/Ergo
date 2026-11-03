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

	private struct CustomViewMenuButton<Content: View, Header: View>: UIViewRepresentable {
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

		@MainActor
		final class Coordinator: NSObject {
			var parent: CustomViewMenuButton
			weak var button: UIButton?
			var didLogElementAPIError = false
			var didLogHeaderAPIError = false
			var didLogOnSelectAPIError = false

			init(_ parent: CustomViewMenuButton) {
				self.parent = parent
			}

			func dismissMenu() {
				button?.interactions.compactMap { $0 as? UIContextMenuInteraction }.first?.dismissMenu()
			}

			func makeMenu(for button: UIButton) -> UIMenu {
				self.button = button
				var children: [UIMenuElement] = parent.actions.map { action in
					UIAction(
						title: action.title,
						image: UIImage(systemName: action.systemImage),
						attributes: action.isDestructive ? .destructive : []
					) { _ in
						action.handler()
					}
				}
				if let customElement = makeCustomElement() {
					children.insert(customElement, at: 0)
				}
				let menu = UIMenu(title: "", children: children)
				if let header = parent.header {
					installHeaderProvider(header, on: menu)
				}
				return menu
			}

			private func makeCustomElement() -> UIMenuElement? {
				let selector = NSSelectorFromString("elementWithViewProvider:")
				guard let elementClass = NSClassFromString("UICustomViewMenuElement") as? NSObject.Type,
				      elementClass.responds(to: selector)
				else {
					logElementAPIError()
					return nil
				}
				let provider: @convention(block) () -> UIView = { [weak self] in
					guard let self else { return UIView(frame: .zero) }
					let dismiss: () -> Void = { [weak self] in self?.dismissMenu() }
					return UIHostingConfiguration {
						self.parent.content(dismiss)
							.frame(width: self.parent.width)
							.fixedSize(horizontal: false, vertical: true)
					}
					.margins(.all, 0)
					.makeContentView()
				}
				guard let element = elementClass.perform(selector, with: provider)?.takeUnretainedValue() as? UIMenuElement else {
					logElementAPIError()
					return nil
				}
				if let onSelect = parent.onSelect {
					installPrimaryActionHandler(onSelect, on: element)
				}
				return element
			}

			private func installHeaderProvider(_ header: @escaping () -> Header, on element: UIMenu) {
				let selector = NSSelectorFromString("setHeaderViewProvider:")
				guard element.responds(to: selector), let method = element.method(for: selector) else {
					if !didLogHeaderAPIError {
						didLogHeaderAPIError = true
						print("[CustomViewMenu] private header setter is unavailable; ignoring the requested menu header.")
					}
					return
				}
				let width = parent.width
				let provider: @convention(block) () -> UIView = {
					UIHostingConfiguration {
						header()
							.frame(width: width)
							.fixedSize(horizontal: false, vertical: true)
					}
					.margins(.all, 0)
					.makeContentView()
				}
				typealias Setter = @convention(c) (AnyObject, Selector, @escaping @convention(block) () -> UIView) -> Void
				unsafeBitCast(method, to: Setter.self)(element, selector, provider)
			}

			private func installPrimaryActionHandler(_ handler: @escaping () -> Void, on element: UIMenuElement) {
				let selector = NSSelectorFromString("setPrimaryActionHandler:")
				guard element.responds(to: selector), let method = element.method(for: selector) else {
					if !didLogOnSelectAPIError {
						didLogOnSelectAPIError = true
						print("[CustomViewMenu] private primary-action setter is unavailable; ignoring the requested onSelect handler.")
					}
					return
				}
				let block: @convention(block) () -> Void = handler
				typealias Setter = @convention(c) (AnyObject, Selector, @escaping @convention(block) () -> Void) -> Void
				unsafeBitCast(method, to: Setter.self)(element, selector, block)
			}

			private func logElementAPIError() {
				guard !didLogElementAPIError else { return }
				didLogElementAPIError = true
				print("[CustomViewMenu] private custom menu element class or factory is unavailable; falling back to standard actions.")
			}
		}
	}

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
