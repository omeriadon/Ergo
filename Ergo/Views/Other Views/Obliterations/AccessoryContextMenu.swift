import ObjectiveC.runtime
import SwiftUI
import UIKit

/// Accessory positioning follows https://github.com/sebjvidal/_UIContextMenuAccessoryView-Demo/tree/swift.
/// A SwiftUI source view with a native context menu and a custom accessory view.
///
/// The accessory uses UIKit's private `_UIContextMenuAccessoryView` class. This
/// can break on future OS releases and is unsuitable for App Store submission.
/// Accessory content floats beside the menu; it is not inserted as a menu row.
/// Set `accessorySize` to fit your custom content.
@available(iOS 16.0, *)
@MainActor
public struct AccessoryContextMenu<Source: View, Accessory: View>: UIViewControllerRepresentable {
	public enum Activation: Equatable {
		case longPress
		case tap
	}

	public struct Action {
		public let title: String
		public let systemImage: String?
		public let handler: () -> Void

		public init(
			title: String,
			systemImage: String? = nil,
			handler: @escaping () -> Void
		) {
			self.title = title
			self.systemImage = systemImage
			self.handler = handler
		}
	}

	private let source: () -> Source
	private let actions: [Action]
	private let accessorySize: CGSize
	private let activation: Activation
	private let accessory: (@escaping () -> Void) -> Accessory

	public init(
		actions: [Action],
		accessorySize: CGSize = CGSize(width: 300, height: 64),
		activation: Activation = .longPress,
		@ViewBuilder source: @escaping () -> Source,
		@ViewBuilder accessory: @escaping (@escaping () -> Void) -> Accessory
	) {
		self.source = source
		self.actions = actions
		self.accessorySize = accessorySize
		self.activation = activation
		self.accessory = accessory
	}

	public func makeCoordinator() -> Coordinator {
		Coordinator(
			source: AnyView(source()),
			actions: actions,
			accessorySize: accessorySize,
			activation: activation,
			accessory: { dismiss in
				AnyView(accessory(dismiss))
			}
		)
	}

	public func makeUIViewController(context: Context) -> UIHostingController<AnyView> {
		context.coordinator.makeView()
	}

	public func updateUIViewController(_: UIHostingController<AnyView>, context: Context) {
		context.coordinator.update(
			source: AnyView(source()),
			actions: actions,
			accessorySize: accessorySize,
			activation: activation,
			accessory: { dismiss in
				AnyView(accessory(dismiss))
			}
		)
	}

	public func sizeThatFits(
		_ proposal: ProposedViewSize,
		uiViewController _: UIHostingController<AnyView>,
		context: Context
	) -> CGSize? {
		context.coordinator.sourceHostingView.sizeThatFits(
			in: proposal.replacingUnspecifiedDimensions(
				by: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
			)
		)
	}

	public static func dismantleUIViewController(
		_: UIHostingController<AnyView>,
		coordinator: Coordinator
	) {
		coordinator.tearDown()
	}

	public final class Coordinator: NSObject, UIContextMenuInteractionDelegate {
		fileprivate let sourceHostingView: UIHostingController<AnyView>
		private final class AccessoryEntry {
			let configuration: UIContextMenuConfiguration
			let host: UIHostingController<AnyView>
			let view: UIView

			init(configuration: UIContextMenuConfiguration, host: UIHostingController<AnyView>, view: UIView) {
				self.configuration = configuration
				self.host = host
				self.view = view
			}
		}

		private var accessoryEntries: [ObjectIdentifier: AccessoryEntry] = [:]
		private var actions: [Action]
		private var accessorySize: CGSize
		private var activation: AccessoryContextMenu<Source, Accessory>.Activation
		private var accessory: (@escaping () -> Void) -> AnyView
		private var interaction: UIContextMenuInteraction?
		private weak var tapRecognizer: UITapGestureRecognizer?
		private var installedActivation: AccessoryContextMenu<Source, Accessory>.Activation?
		private var tapOpening = false
		private var activeConfiguration: UIContextMenuConfiguration?

		fileprivate init(
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

		fileprivate func makeView() -> UIHostingController<AnyView> {
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

		fileprivate func update(
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

		private func configureActivation() {
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

		@objc private func openMenuFromTap(_ recognizer: UITapGestureRecognizer) {
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

		private func resetTapOpening() {
			tapOpening = false
		}

		fileprivate func tearDown() {
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

		private struct Anchor {
			var attachment: UInt64 = 1
			var alignment: UInt64 = 8
			var attachmentOffset: Double = 0
			var alignmentOffset: Double = 0
			var gravity: Int64 = 0
		}

		private func setTopTrailingAnchor(on view: UIView, class accessoryClass: UIView.Type) {
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

@available(iOS 26.0, *)
@MainActor
private final class AccessoryMenuInteraction: UIContextMenuInteraction {
	var accessoryProvider: ((UIContextMenuConfiguration) -> [UIView])?

	/// Recent UIKit versions leave the private delegate callback unused.
	@objc(_delegate_getAccessoryViewsForConfiguration:)
	func accessoryViews(for configuration: UIContextMenuConfiguration) -> [UIView] {
		accessoryProvider?(configuration) ?? []
	}
}

/// One source view with a tall, scrolling accessory inside the context menu.
@available(iOS 16.0, *)
@MainActor
private struct SoftScrollEdgeEffect: ViewModifier {
	func body(content: Content) -> some View {
		if #available(iOS 26.0, *) {
			content.scrollEdgeEffectStyle(.soft, for: .all)
		} else {
			content
		}
	}
}

/// One source view with a tall, scrolling accessory inside the context menu.
@available(iOS 16.0, *)
@MainActor
public struct AccessoryContextMenuDemo: View {
	@State private var selection = "Tap for actions"

	public init() {}

	public var body: some View {
		AccessoryContextMenu(
			actions: [
				.init(title: "Copy", systemImage: "doc.on.doc") {
					UIPasteboard.general.string = selection
				},
				.init(title: "Reset", systemImage: "arrow.counterclockwise") {
					selection = "Tap for actions"
				},
			],
			accessorySize: CGSize(width: 280, height: 320),
			activation: .tap,
			source: {
				Label(selection, systemImage: "ellipsis.circle")
					.font(.headline)
					.foregroundStyle(.white)
					.padding(.horizontal, 24)
					.padding(.vertical, 18)
					.background(.blue, in: RoundedRectangle(cornerRadius: 22))
					.accessibilityHint("Tap to show the scrolling menu")
					.accessibilityIdentifier("contextMenu.source")
			},
			accessory: { dismiss in
				VStack(alignment: .leading, spacing: 8) {
					Label("Choose an action", systemImage: "slider.horizontal.3")
						.font(.headline)
						.padding(.horizontal, 12)
						.padding(.top, 8)
						.accessibilityAddTraits(.isHeader)

					ScrollView {
						LazyVStack(spacing: 4) {
							ForEach(1 ... 30, id: \.self) { number in
								Button {
									selection = "Selected action \(number)"
									dismiss()
								} label: {
									Label("Action \(number)", systemImage: "star")
										.frame(maxWidth: .infinity, alignment: .leading)
										.padding(.horizontal, 12)
										.frame(minHeight: 44)
										.contentShape(Rectangle())
								}
								.buttonStyle(.plain)
								.accessibilityLabel("Action \(number)")
								.accessibilityIdentifier("contextMenu.action.\(number)")
							}
						}
					}
					.modifier(SoftScrollEdgeEffect())
					.accessibilityIdentifier("contextMenu.scrollingAccessory")
				}
				.padding(8)
				.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
				.clipShape(RoundedRectangle(cornerRadius: 22))
			}
		)
		.padding()
	}
}
