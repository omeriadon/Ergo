//
//  CustomAlertAction.swift
//  Ergo
//
//  Created by Adon Omeri on 3/11/2026.
//

// CustomAlert.swift
//
// Usage:
// Embed CustomAlertDemo() inside an existing NavigationStack. Do not nest NavigationStacks.
// Standalone use: NavigationStack { CustomAlertDemo() } or open its Xcode preview.
// Text("Account")
//     .customAlert(title: "Account", message: "", isPresented: $showAlert) { dismiss in
//         Button(role: .cancel) { dismiss() } label: {
//             Label("Close", systemImage: "xmark")
//         }
//         .accessibilityIdentifier("account-alert-close")
//     }
//
// contentHeight is the height available for content, including its 16-point padding.
// Native actions can be supplied with actions: [.init(title: "Cancel", role: .cancel)].
// The header overload supports headerPlacement: .aboveTitle or .separated.
// This file uses private UIAlertController APIs to place arbitrary SwiftUI content
// in an alert. Private APIs can change or be rejected by App Review. Inject any
// required environment objects into the content explicitly.

import SwiftUI

#if os(iOS)
	import UIKit

	public struct CustomAlertAction {
		public enum Role {
			case normal
			case cancel
			case destructive
		}

		public let title: String
		public let role: Role
		public let handler: (() -> Void)?

		public init(
			title: String,
			role: Role = .normal,
			handler: (() -> Void)? = nil
		) {
			self.title = title
			self.role = role
			self.handler = handler
		}
	}

	public enum CustomAlertHeaderPlacement {
		case aboveTitle
		case separated
	}

	@MainActor
	private final class CustomAlertController: UIAlertController {
		var didDisappear: (() -> Void)?

		override func viewDidDisappear(_ animated: Bool) {
			super.viewDidDisappear(animated)
			didDisappear?()
		}
	}

	@MainActor
	private final class CustomAlertPresenter: UIViewController {
		var update: (() -> Void)?

		override func viewDidAppear(_ animated: Bool) {
			super.viewDidAppear(animated)
			update?()
		}
	}

	private struct CustomAlertBridge<Content: View, Header: View>: UIViewControllerRepresentable {
		@Binding var isPresented: Bool
		let title: String?
		let message: String?
		let contentHeight: CGFloat
		let headerPlacement: CustomAlertHeaderPlacement?
		let header: () -> Header
		let content: (@escaping () -> Void) -> Content
		let actions: [CustomAlertAction]

		func makeCoordinator() -> Coordinator {
			Coordinator(self)
		}

		func makeUIViewController(context: Context) -> CustomAlertPresenter {
			let presenter = CustomAlertPresenter()
			presenter.view.backgroundColor = .clear
			presenter.view.isUserInteractionEnabled = false
			presenter.update = { [weak presenter, weak coordinator = context.coordinator] in
				guard let presenter, let coordinator else { return }
				coordinator.presentIfNeeded(from: presenter)
			}
			return presenter
		}

		func updateUIViewController(_ presenter: CustomAlertPresenter, context: Context) {
			let wasPresented = context.coordinator.parent.isPresented
			context.coordinator.parent = self
			if wasPresented != isPresented {
				context.coordinator.presentationRequestID += 1
				if !isPresented {
					context.coordinator.isPresentationPending = false
				}
			}
			DispatchQueue.main.async { [weak presenter, weak coordinator = context.coordinator] in
				guard let presenter, let coordinator else { return }
				coordinator.synchronize(from: presenter)
			}
		}

		static func dismantleUIViewController(_ presenter: CustomAlertPresenter, coordinator: Coordinator) {
			coordinator.isDismantled = true
			coordinator.dismissPresentedAlertIfNeeded()
			presenter.update = nil
		}

		@MainActor
		final class Coordinator: NSObject {
			var parent: CustomAlertBridge
			var alert: CustomAlertController?
			var hosting: UIHostingController<AnyView>?
			var headerHosting: UIHostingController<Header>?
			var isDismantled = false
			var isPresentationPending = false
			var isDismissing = false
			var hasBeenAttached = false
			var didLogBlockedRequest = false
			var presentationRequestID = 0
			var didDeferForTransition = false
			var didLogContentAPIError = false
			var didLogHeaderAPIError = false
			var lastTitle: String?
			var lastMessage: String?
			var lastContentHeight: CGFloat?
			var lastHeaderPlacement: CustomAlertHeaderPlacement?
			var headerWidthConstraint: NSLayoutConstraint?
			var headerHeightConstraint: NSLayoutConstraint?

			init(_ parent: CustomAlertBridge) {
				self.parent = parent
			}

			func synchronize(from presenter: UIViewController) {
				guard !isDismantled else { return }
				guard presenter.viewIfLoaded?.window != nil else {
					if hasBeenAttached, parent.isPresented {
						resetPresentationRequest("presenter is no longer attached to a window")
					}
					return
				}
				hasBeenAttached = true
				if parent.isPresented {
					if let alert {
						if lastTitle != parent.title {
							alert.title = parent.title
							lastTitle = parent.title
						}
						if lastMessage != parent.message {
							alert.message = parent.message
							lastMessage = parent.message
						}
						hosting?.rootView = contentView()
						let contentHeight = boundedContentHeight
						if lastContentHeight != contentHeight {
							hosting?.preferredContentSize = CGSize(width: 270, height: contentHeight)
							lastContentHeight = contentHeight
						}
						headerHosting?.rootView = parent.header()
						if lastHeaderPlacement != parent.headerPlacement {
							if let headerHosting {
								configureHeaderSizing(headerHosting)
							}
							lastHeaderPlacement = parent.headerPlacement
						}
					} else {
						presentIfNeeded(from: presenter)
					}
				} else {
					didLogBlockedRequest = false
					didDeferForTransition = false
					cancelPendingPresentation()
					dismissPresentedAlertIfNeeded()
				}
			}

			func presentIfNeeded(from presenter: UIViewController) {
				guard !isDismantled, parent.isPresented, alert == nil, !isPresentationPending, !didLogBlockedRequest else { return }
				guard presenter.viewIfLoaded?.window != nil else {
					if hasBeenAttached {
						resetPresentationRequest("presenter is no longer attached to a window")
					}
					return
				}
				hasBeenAttached = true

				let requestStarted = CACurrentMediaTime()
				isPresentationPending = true
				print("[CustomAlert] presentation request started")

				let presentingController = localPresentingController(from: presenter)
				let transitionCoordinator = presentingController.transitionCoordinator ?? presenter.transitionCoordinator
				if !didDeferForTransition, let transitionCoordinator, waitForTransitionCompletion(
					transitionCoordinator,
					presenter: presenter
				) {
					return
				}
				guard presentingController.presentedViewController == nil else {
					resetPresentationRequest("local presenter already has presented UI")
					return
				}
				var ancestor = presentingController.parent
				while let controller = ancestor {
					guard controller.presentedViewController == nil else {
						resetPresentationRequest("an ancestor controller already has presented UI")
						return
					}
					ancestor = controller.parent
				}

				let hosting = UIHostingController(rootView: contentView())
				hosting.view.backgroundColor = .clear
				let contentHeight = boundedContentHeight
				hosting.preferredContentSize = CGSize(width: 270, height: contentHeight)

				let alert = CustomAlertController(title: parent.title, message: parent.message, preferredStyle: .alert)
				guard installContentController(hosting, in: alert) else {
					isPresentationPending = false
					resetPresentationRequest("private content view controller setter is unavailable")
					return
				}
				self.hosting = hosting
				lastTitle = parent.title
				lastMessage = parent.message
				lastContentHeight = contentHeight
				lastHeaderPlacement = parent.headerPlacement
				if let placement = parent.headerPlacement {
					let selector = NSSelectorFromString(
						placement == .aboveTitle
							? "_setHeaderContentViewController:"
							: "_setSeparatedHeaderContentViewController:"
					)
					if alert.responds(to: selector) {
						let headerHosting = UIHostingController(rootView: parent.header())
						headerHosting.view.backgroundColor = .clear
						configureHeaderSizing(headerHosting)
						alert.perform(selector, with: headerHosting)
						self.headerHosting = headerHosting
					} else if !didLogHeaderAPIError {
						didLogHeaderAPIError = true
						print("[CustomAlert] private header setter is unavailable; ignoring the requested alert header.")
					}
				}
				for action in parent.actions {
					let style: UIAlertAction.Style = switch action.role {
						case .normal: .default
						case .cancel: .cancel
						case .destructive: .destructive
					}
					alert.addAction(UIAlertAction(title: action.title, style: style) { [weak self] _ in
						action.handler?()
						self?.parent.isPresented = false
					})
				}
				alert.didDisappear = { [weak self, weak alert] in
					guard let self, self.alert === alert else { return }
					self.alert = nil
					self.hosting = nil
					headerHosting = nil
					headerWidthConstraint = nil
					headerHeightConstraint = nil
					isPresentationPending = false
					if parent.isPresented {
						resetPresentationRequest("alert was dismissed while its request remained active")
					}
				}
				self.alert = alert
				isPresentationPending = false
				let preparationMilliseconds = (CACurrentMediaTime() - requestStarted) * 1000
				print("[CustomAlert] presentation setup completed in \(String(format: "%.1f", preparationMilliseconds)) ms")
				let presentationStarted = CACurrentMediaTime()
				print("[CustomAlert] UIKit presentation started")
				presentingController.present(alert, animated: true) { [self] in
					let presentationMilliseconds = (CACurrentMediaTime() - presentationStarted) * 1000
					let totalMilliseconds = (CACurrentMediaTime() - requestStarted) * 1000
					print("[CustomAlert] UIKit presentation completed in \(String(format: "%.1f", presentationMilliseconds)) ms (total \(String(format: "%.1f", totalMilliseconds)) ms)")
					if isDismantled || !parent.isPresented {
						dismissPresentedAlertIfNeeded()
					}
				}
			}

			func dismissPresentedAlertIfNeeded() {
				guard let alert, !alert.isBeingPresented, !isDismissing else { return }
				isDismissing = true
				self.alert = nil
				hosting = nil
				headerHosting = nil
				alert.dismiss(animated: true) { [weak self] in
					guard let self else { return }
					isDismissing = false
				}
			}

			private var boundedContentHeight: CGFloat {
				let height = parent.contentHeight
				guard height.isFinite, height > 0 else { return 180 }
				return max(1, height)
			}

			private func configureHeaderSizing(_ hosting: UIHostingController<Header>) {
				hosting.sizingOptions = []
				let measuredSize = hosting.sizeThatFits(in: CGSize(width: 270, height: 400))
				let height = measuredSize.height.isFinite && measuredSize.height > 0
					? min(measuredSize.height, 400)
					: 1
				hosting.preferredContentSize = CGSize(width: 270, height: height)
				hosting.view.translatesAutoresizingMaskIntoConstraints = false
				headerWidthConstraint?.isActive = false
				headerHeightConstraint?.isActive = false
				let widthConstraint = hosting.view.widthAnchor.constraint(equalToConstant: 270)
				let heightConstraint = hosting.view.heightAnchor.constraint(equalToConstant: height)
				widthConstraint.isActive = true
				heightConstraint.isActive = true
				headerWidthConstraint = widthConstraint
				headerHeightConstraint = heightConstraint
			}

			private func contentView() -> AnyView {
				AnyView(
					parent.content { [weak self] in
						self?.parent.isPresented = false
					}
					.frame(maxWidth: .infinity)
					.padding(16)
				)
			}

			private func localPresentingController(from presenter: UIViewController) -> UIViewController {
				var screen = presenter
				while let ancestor = screen.parent,
				      !(ancestor is UINavigationController),
				      !(ancestor is UITabBarController),
				      !(ancestor is UISplitViewController)
				{
					screen = ancestor
				}
				return screen
			}

			private func resetPresentationRequest(_ reason: String) {
				guard !didLogBlockedRequest else { return }
				didLogBlockedRequest = true
				presentationRequestID += 1
				let resetRequestID = presentationRequestID
				isPresentationPending = false
				print("[CustomAlert] presentation request skipped: \(reason); resetting isPresented")
				DispatchQueue.main.async { [weak self] in
					guard let self,
					      presentationRequestID == resetRequestID,
					      !self.isDismantled,
					      parent.isPresented else { return }
					parent.isPresented = false
				}
			}

			private func waitForTransitionCompletion(
				_ transitionCoordinator: UIViewControllerTransitionCoordinator,
				presenter: UIViewController
			) -> Bool {
				didDeferForTransition = true
				presentationRequestID += 1
				let requestID = presentationRequestID
				let accepted = transitionCoordinator.animate(alongsideTransition: nil) { [weak self, weak presenter] _ in
					guard let self,
					      let presenter,
					      presentationRequestID == requestID,
					      !self.isDismantled else { return }
					isPresentationPending = false
					guard parent.isPresented else { return }
					guard presenter.viewIfLoaded?.window != nil else {
						resetPresentationRequest("presenter detached before transition completed")
						return
					}
					print("[CustomAlert] presentation transition completed; resuming request")
					presentIfNeeded(from: presenter)
				}
				guard accepted else {
					return false
				}
				isPresentationPending = true
				print("[CustomAlert] presentation request waiting for active transition")
				return true
			}

			private func cancelPendingPresentation() {
				guard isPresentationPending else { return }
				presentationRequestID += 1
				isPresentationPending = false
			}

			private func installContentController(_ hosting: UIViewController, in alert: UIAlertController) -> Bool {
				let selector = NSSelectorFromString("setContentViewController:")
				guard alert.responds(to: selector), let method = alert.method(for: selector) else {
					if !didLogContentAPIError {
						didLogContentAPIError = true
						print("[CustomAlert] private content view controller setter is unavailable; dismissing the custom alert request.")
					}
					return false
				}
				typealias Setter = @convention(c) (AnyObject, Selector, UIViewController) -> Void
				let setter = unsafeBitCast(method, to: Setter.self)
				setter(alert, selector, hosting)
				return true
			}
		}
	}

	public extension View {
		func customAlert(
			title: String? = nil,
			message: String? = nil,
			isPresented: Binding<Bool>,
			contentHeight: CGFloat = 180,
			headerPlacement: CustomAlertHeaderPlacement? = .aboveTitle,
			@ViewBuilder header: @escaping () -> some View,
			@ViewBuilder content: @escaping (@escaping () -> Void) -> some View,
			actions: [CustomAlertAction] = []
		) -> some View {
			background(
				CustomAlertBridge(
					isPresented: isPresented,
					title: title,
					message: message,
					contentHeight: contentHeight,
					headerPlacement: headerPlacement,
					header: header,
					content: content,
					actions: actions
				)
				.frame(width: 0, height: 0)
			)
		}

		func customAlert(
			title: String? = nil,
			message: String? = nil,
			isPresented: Binding<Bool>,
			contentHeight: CGFloat = 180,
			@ViewBuilder content: @escaping (@escaping () -> Void) -> some View,
			actions: [CustomAlertAction] = []
		) -> some View {
			customAlert(
				title: title,
				message: message,
				isPresented: isPresented,
				contentHeight: contentHeight,
				headerPlacement: nil,
				header: { EmptyView() },
				content: content,
				actions: actions
			)
		}
	}

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
