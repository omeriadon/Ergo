//
//  AccessoryContextMenu+Coordinator.swift
//  Ergo
//
//  Created by Adon Omeri on 8/11/2026.
//

import ObjectiveC.runtime
import SwiftUI
import UIKit

@available(iOS 16.0, *)
public extension AccessoryContextMenu {
	final class Coordinator: NSObject, UIContextMenuInteractionDelegate {
		let sourceHostingView: UIHostingController<AnyView>
		final class AccessoryEntry {
			let configuration: UIContextMenuConfiguration
			let host: UIHostingController<AnyView>
			let view: UIView

			init(configuration: UIContextMenuConfiguration, host: UIHostingController<AnyView>, view: UIView) {
				self.configuration = configuration
				self.host = host
				self.view = view
			}
		}

		var accessoryEntries: [ObjectIdentifier: AccessoryEntry] = [:]
		var actions: [Action]
		var accessorySize: CGSize
		var activation: AccessoryContextMenu<Source, Accessory>.Activation
		var accessory: (@escaping () -> Void) -> AnyView
		var interaction: UIContextMenuInteraction?
		private weak var tapRecognizer: UITapGestureRecognizer?
		var installedActivation: AccessoryContextMenu<Source, Accessory>.Activation?
		var tapOpening = false
		var activeConfiguration: UIContextMenuConfiguration?

		init(
			source: AnyView,
			actions: [Action],
			accessorySize: CGSize,
			activation: AccessoryContextMenu<Source, Accessory>.Activation,
			accessory: @escaping (@escaping () -> Void) -> AnyView
		) {
			sourceHostingView = UIHostingController(rootView: source)
			self.actions = actions
			self.accessorySize = accessorySize
			self.activation = activation
			self.accessory = accessory
		}

		func makeView() -> UIHostingController<AnyView> {
			sourceHostingView.view.backgroundColor = .clear
			let menuInteraction: UIContextMenuInteraction
			if #available(iOS 26.0, *) {
				let accessoryInteraction = AccessoryMenuInteraction(delegate: self)
				accessoryInteraction.accessoryProvider = { [weak self, weak accessoryInteraction] configuration in
					guard let self, let accessoryInteraction else {
						return []
					}
					return accessories(for: accessoryInteraction, configuration: configuration)
				}
				menuInteraction = accessoryInteraction
			} else {
				menuInteraction = UIContextMenuInteraction(delegate: self)
			}
			interaction = menuInteraction
			sourceHostingView.view.addInteraction(menuInteraction)
			configureActivation()
			return sourceHostingView
		}

		func update(
			source: AnyView,
			actions: [Action],
			accessorySize: CGSize,
			activation: AccessoryContextMenu<Source, Accessory>.Activation,
			accessory: @escaping (@escaping () -> Void) -> AnyView
		) {
			sourceHostingView.rootView = source
			self.actions = actions
			self.accessorySize = accessorySize
			self.activation = activation
			self.accessory = accessory
			configureActivation()
			for entry in accessoryEntries.values {
				entry.host.rootView = accessory { [weak self] in
					self?.interaction?.dismissMenu()
				}
			}
		}

		func configureActivation() {
			if installedActivation == activation {
				return
			}

			if let tapRecognizer {
				sourceHostingView.view.removeGestureRecognizer(tapRecognizer)
				self.tapRecognizer = nil
			}

			installedActivation = activation

			guard activation == .tap else {
				return
			}

			let recognizer = UITapGestureRecognizer(target: self, action: #selector(openMenuFromTap(_:)))
			recognizer.accessibilityLabel = "Show context menu"
			sourceHostingView.view.addGestureRecognizer(recognizer)
			tapRecognizer = recognizer
		}

		@objc func openMenuFromTap(_ recognizer: UITapGestureRecognizer) {
			guard recognizer.state == .ended, !tapOpening else {
				return
			}
			tapOpening = true

			guard let interaction,
			      let method = class_getInstanceMethod(
			      	type(of: interaction),
			      	NSSelectorFromString("_presentMenuAtLocation:")
			      )
			else {
				return resetTapOpening()
			}

			let selector = NSSelectorFromString("_presentMenuAtLocation:")
			guard method_getNumberOfArguments(method) == 3,
			      let argumentType = method_copyArgumentType(method, 2)
			else {
				return resetTapOpening()
			}
			let returnType = method_copyReturnType(method)
			defer {
				free(UnsafeMutableRawPointer(mutating: argumentType))
				free(UnsafeMutableRawPointer(mutating: returnType))
			}

			var argumentSize = 0
			var argumentAlignment = 0
			guard String(cString: argumentType).hasPrefix("{CGPoint=") else {
				return resetTapOpening()
			}
			NSGetSizeAndAlignment(argumentType, &argumentSize, &argumentAlignment)
			guard argumentSize == MemoryLayout<CGPoint>.size,
			      String(cString: returnType) == "v"
			else {
				return resetTapOpening()
			}

			let implementation = method_getImplementation(method)
			let call = unsafeBitCast(
				implementation,
				to: (@convention(c) (AnyObject, Selector, CGPoint) -> Void).self
			)
			let location = recognizer.location(in: sourceHostingView.view)
			DispatchQueue.main.async { [weak self, weak interaction] in
				guard let self, let interaction,
				      sourceHostingView.view.window != nil
				else {
					self?.tapOpening = false
					return
				}
				call(interaction, selector, location)
			}
		}

		func resetTapOpening() {
			tapOpening = false
		}

		func tearDown() {
			interaction?.dismissMenu()
			accessoryEntries.removeAll()
			activeConfiguration = nil
			tapOpening = false
		}

		public func contextMenuInteraction(
			_: UIContextMenuInteraction,
			configurationForMenuAtLocation _: CGPoint
		) -> UIContextMenuConfiguration? {
			let configuration = UIContextMenuConfiguration(actionProvider: { [actions] _ in
				UIMenu(children: actions.map { action in
					let image = action.systemImage.flatMap { UIImage(systemName: $0) }
					return UIAction(title: action.title, image: image) { _ in
						action.handler()
					}
				})
			})
			if configuration.responds(to: NSSelectorFromString("setPreferredMenuAlignment:")) {
				configuration.setValue(3, forKey: "preferredMenuAlignment")
			}
			activeConfiguration = configuration
			return configuration
		}

		public func contextMenuInteraction(
			_: UIContextMenuInteraction,
			configuration _: UIContextMenuConfiguration,
			highlightPreviewForItemWithIdentifier _: any NSCopying
		) -> UITargetedPreview? {
			let parameters = UIPreviewParameters()
			parameters.visiblePath = UIBezierPath(
				roundedRect: sourceHostingView.view.bounds,
				cornerRadius: 22
			)
			let preview = UITargetedPreview(view: sourceHostingView.view, parameters: parameters)
			if preview.responds(to: NSSelectorFromString("_setPrefersUnmaskedPlatterStyle:")) {
				preview.setValue(true, forKey: "prefersUnmaskedPlatterStyle")
			}
			return preview
		}

		@objc(_contextMenuInteraction:accessoriesForMenuWithConfiguration:)
		public func accessories(
			for interaction: UIContextMenuInteraction,
			configuration: UIContextMenuConfiguration
		) -> [UIView] {
			let key = ObjectIdentifier(configuration)
			if let entry = accessoryEntries[key] {
				return [entry.view]
			}

			guard let accessoryClass = NSClassFromString("_UIContextMenuAccessoryView") as? UIView.Type else {
				return []
			}

			let accessoryView = accessoryClass.init()
			guard ["setLocation:", "setTrackingAxis:", "setOffset:", "setAnchor:"].allSatisfy({
				accessoryView.responds(to: NSSelectorFromString($0))
			}) else {
				return []
			}
			accessoryView.backgroundColor = .clear
			accessoryView.layer.cornerRadius = 32
			accessoryView.layer.cornerCurve = .continuous
			accessoryView.frame.size = accessorySize
			accessoryView.setValue(1, forKey: "location")
			accessoryView.setValue(3, forKey: "trackingAxis")
			accessoryView.setValue(NSValue(cgPoint: CGPoint(x: -3, y: -16)), forKey: "offset")
			setTopTrailingAnchor(on: accessoryView, class: accessoryClass)

			let host = UIHostingController(rootView: accessory {
				[weak interaction] in
				interaction?.dismissMenu()
			})
			let hosted = host.view!
			hosted.backgroundColor = .clear
			hosted.translatesAutoresizingMaskIntoConstraints = false
			accessoryView.addSubview(hosted)
			NSLayoutConstraint.activate([
				hosted.leadingAnchor.constraint(equalTo: accessoryView.leadingAnchor),
				hosted.trailingAnchor.constraint(equalTo: accessoryView.trailingAnchor),
				hosted.topAnchor.constraint(equalTo: accessoryView.topAnchor),
				hosted.bottomAnchor.constraint(equalTo: accessoryView.bottomAnchor),
			])
			// UIKit can request accessories again while the same menu animates.
			accessoryEntries[key] = AccessoryEntry(configuration: configuration, host: host, view: accessoryView)
			return [accessoryView]
		}

		public func contextMenuInteraction(
			_: UIContextMenuInteraction,
			willEndFor configuration: UIContextMenuConfiguration,
			animator: UIContextMenuInteractionAnimating?
		) {
			let key = ObjectIdentifier(configuration)
			let endingEntry = accessoryEntries[key]
			let cleanup = { [weak self, configuration, endingEntry] in
				guard let self else { return }
				if accessoryEntries[key] === endingEntry {
					accessoryEntries.removeValue(forKey: key)
				}
				if activeConfiguration === configuration {
					activeConfiguration = nil
					tapOpening = false
				}
			}
			if let animator {
				animator.addCompletion(cleanup)
			} else {
				cleanup()
			}
		}

		struct Anchor {
			var attachment: UInt64 = 1
			var alignment: UInt64 = 8
			var attachmentOffset: Double = 0
			var alignmentOffset: Double = 0
			var gravity: Int64 = 0
		}

		func setTopTrailingAnchor(on view: UIView, class accessoryClass: UIView.Type) {
			let selector = NSSelectorFromString("setAnchor:")
			guard let method = class_getInstanceMethod(accessoryClass, selector),
			      let encoding = method_copyArgumentType(method, 2)
			else {
				return
			}
			defer { free(UnsafeMutableRawPointer(mutating: encoding)) }

			var size = 0
			var alignment = 0
			NSGetSizeAndAlignment(encoding, &size, &alignment)
			guard String(cString: encoding).hasPrefix("{"),
			      size == 40,
			      size == MemoryLayout<Anchor>.size,
			      alignment == MemoryLayout<Anchor>.alignment
			else {
				return
			}

			var anchor = Anchor()
			let value = withUnsafePointer(to: &anchor) { pointer in
				NSValue(bytes: pointer, objCType: encoding)
			}
			view.setValue(value, forKey: "anchor")
		}
	}
}
