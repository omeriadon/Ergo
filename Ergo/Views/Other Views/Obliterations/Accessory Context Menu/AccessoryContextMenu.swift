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
}
