//
//  CustomViewMenuButton+Coordinator.swift
//  Ergo
//
//  Created by Adon Omeri on 8/11/2026.
//

import SwiftUI

#if os(iOS)
	import UIKit

	extension CustomViewMenuButton {
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

			func makeCustomElement() -> UIMenuElement? {
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
				guard let element = unsafe elementClass.perform(selector, with: provider)?.takeUnretainedValue() as? UIMenuElement else {
					logElementAPIError()
					return nil
				}
				if let onSelect = parent.onSelect {
					installPrimaryActionHandler(onSelect, on: element)
				}
				return element
			}

			func installHeaderProvider(_ header: @escaping () -> Header, on element: UIMenu) {
				let selector = NSSelectorFromString("setHeaderViewProvider:")
				guard element.responds(to: selector), let method = unsafe element.method(for: selector) else {
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
				unsafe unsafeBitCast(method, to: Setter.self)(element, selector, provider)
			}

			func installPrimaryActionHandler(_ handler: @escaping () -> Void, on element: UIMenuElement) {
				let selector = NSSelectorFromString("setPrimaryActionHandler:")
				guard element.responds(to: selector), let method = unsafe element.method(for: selector) else {
					if !didLogOnSelectAPIError {
						didLogOnSelectAPIError = true
						print("[CustomViewMenu] private primary-action setter is unavailable; ignoring the requested onSelect handler.")
					}
					return
				}
				let block: @convention(block) () -> Void = handler
				typealias Setter = @convention(c) (AnyObject, Selector, @escaping @convention(block) () -> Void) -> Void
				unsafe unsafeBitCast(method, to: Setter.self)(element, selector, block)
			}

			func logElementAPIError() {
				guard !didLogElementAPIError else { return }
				didLogElementAPIError = true
				print("[CustomViewMenu] private custom menu element class or factory is unavailable; falling back to standard actions.")
			}
		}
	}
#endif
