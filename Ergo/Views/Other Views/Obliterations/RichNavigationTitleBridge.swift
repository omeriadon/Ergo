//
//  RichNavigationTitleBridge.swift
//  Ergo
//
//  Created by Adon Omeri on 3/11/2026.
//

// RichNavigationTitle.swift
//
// Usage inside an existing NavigationStack. Do not nest NavigationStacks.
// Standalone use: NavigationStack { RichNavigationTitleDemo() } or open its Xcode preview.
// NavigationStack {
//     Text("Details")
//         .richNavigationTitle(height: 84, width: 160) {
//             VStack(spacing: 4) {
//                 Image(systemName: "person.crop.circle.fill")
//                     .font(.system(size: 44))
//                     .accessibilityHidden(true)
//                 Text("Seb Vidal").font(.caption)
//             }
//             .accessibilityElement(children: .combine)
//             .accessibilityIdentifier("rich-navigation-title")
//         }
// }
//
// This uses private UINavigationBar title-view APIs when available. Private APIs
// can change or be rejected by App Review. It falls back to a public titleView
// at the standard 44-point height when those APIs are unavailable.

import SwiftUI

#if os(iOS)
	import ObjectiveC
	import UIKit

	public extension View {
		func richNavigationTitle(
			height: CGFloat = 84,
			width: CGFloat = 160,
			@ViewBuilder content: () -> some View
		) -> some View {
			navigationBarTitleDisplayMode(.inline)
				.background(
					RichNavigationTitleBridge(
						height: height,
						width: width,
						content: content()
					)
					.frame(width: 0, height: 0)
				)
		}
	}

	private struct RichNavigationTitleBridge<Content: View>: UIViewControllerRepresentable {
		let height: CGFloat
		let width: CGFloat
		let content: Content

		func makeCoordinator() -> Coordinator {
			Coordinator(self)
		}

		func makeUIViewController(context: Context) -> ProbeViewController {
			let probe = ProbeViewController()
			probe.view.backgroundColor = .clear
			probe.view.isUserInteractionEnabled = false
			probe.onAttachment = { [weak coordinator = context.coordinator, weak probe] in
				guard let coordinator, let probe else { return }
				coordinator.apply(to: probe)
			}
			probe.onWillAppear = { [weak coordinator = context.coordinator, weak probe] transition in
				guard let coordinator, let probe else { return }
				coordinator.titleWillAppear(for: probe, transition: transition)
			}
			probe.onDidAppear = { [weak coordinator = context.coordinator, weak probe] in
				guard let coordinator, let probe else { return }
				coordinator.apply(to: probe)
				coordinator.installedTitleView?.alpha = 1
			}
			probe.onWillDisappear = { [weak coordinator = context.coordinator] transition in
				coordinator?.fadeTitle(to: 0, transition: transition)
			}
			return probe
		}

		func updateUIViewController(_ probe: ProbeViewController, context: Context) {
			context.coordinator.parent = self
			DispatchQueue.main.async { [weak coordinator = context.coordinator, weak probe] in
				guard let coordinator, let probe else { return }
				coordinator.apply(to: probe)
			}
		}

		static func dismantleUIViewController(_ probe: ProbeViewController, coordinator: Coordinator) {
			coordinator.isDismantled = true
			coordinator.restore()
			probe.onAttachment = nil
			probe.onWillAppear = nil
			probe.onDidAppear = nil
			probe.onWillDisappear = nil
		}

		@MainActor
		final class ProbeViewController: UIViewController {
			var onAttachment: (() -> Void)?
			var onWillAppear: ((UIViewControllerTransitionCoordinator?) -> Void)?
			var onDidAppear: (() -> Void)?
			var onWillDisappear: ((UIViewControllerTransitionCoordinator?) -> Void)?
			var canInstall = false

			private var activeTransition: UIViewControllerTransitionCoordinator? {
				transitionCoordinator ?? navigationController?.transitionCoordinator
			}

			override func viewWillAppear(_ animated: Bool) {
				super.viewWillAppear(animated)
				canInstall = true
				onWillAppear?(activeTransition)
			}

			/// The title view stays installed while the screen leaves, so the push, pop and
			/// interactive back swipe can scrub its opacity. It is removed in dismantle.
			override func viewWillDisappear(_ animated: Bool) {
				super.viewWillDisappear(animated)
				canInstall = false
				onWillDisappear?(activeTransition)
			}

			override func didMove(toParent parent: UIViewController?) {
				super.didMove(toParent: parent)
				onAttachment?()
			}

			override func viewDidAppear(_ animated: Bool) {
				super.viewDidAppear(animated)
				onDidAppear?()
			}
		}

		@MainActor
		final class Coordinator: NSObject {
			var parent: RichNavigationTitleBridge
			weak var navigationController: UINavigationController?
			weak var installedTitleView: UIView?
			weak var navigationItem: UINavigationItem?
			var hostedContentView: (UIView & UIContentView)?
			var previousTitleView: UIView?
			var widthConstraint: NSLayoutConstraint?
			var heightConstraint: NSLayoutConstraint?
			var didLogPrivateClassFailure = false
			var didLogSetterFailure = false
			var isDismantled = false

			init(_ parent: RichNavigationTitleBridge) {
				self.parent = parent
			}

			func apply(to probe: ProbeViewController) {
				guard !isDismantled, probe.canInstall,
				      probe.viewIfLoaded?.window != nil,
				      let navigation = findNavigationController(from: probe),
				      let owner = probe.owningViewController(for: navigation),
				      navigation.visibleViewController === owner else { return }
				let item = owner.navigationItem
				if navigationItem !== item {
					restore()
				}
				navigationController = navigation
				navigationItem = item
				if installedTitleView == nil {
					previousTitleView = item.titleView
				}

				let titleView = installedTitleView ?? makeTitleView()
				installedTitleView = titleView
				item.titleView = titleView
				configure(titleView: titleView, navigation: navigation)
			}

			func titleWillAppear(for probe: ProbeViewController, transition: UIViewControllerTransitionCoordinator?) {
				let isNew = installedTitleView == nil
				apply(to: probe)
				guard let titleView = installedTitleView else { return }
				if isNew, transition != nil {
					titleView.alpha = 0
				}
				fadeTitle(to: 1, transition: transition)
			}

			/// Driven by the transition coordinator, so an interactive swipe scrubs the fade and a
			/// cancelled one reverses it. Without a transition the change is immediate.
			func fadeTitle(to alpha: CGFloat, transition: UIViewControllerTransitionCoordinator?) {
				guard let titleView = installedTitleView else { return }
				guard let transition else {
					titleView.alpha = alpha
					return
				}
				transition.animate(alongsideTransition: { _ in
					titleView.alpha = alpha
				})
			}

			func restore() {
				if let item = navigationItem, item.titleView === installedTitleView {
					item.titleView = previousTitleView
				}
				widthConstraint?.isActive = false
				heightConstraint?.isActive = false
				hostedContentView?.removeFromSuperview()
				hostedContentView = nil
				installedTitleView = nil
				previousTitleView = nil
				navigationItem = nil
				navigationController = nil
				widthConstraint = nil
				heightConstraint = nil
			}

			private func findNavigationController(from probe: UIViewController) -> UINavigationController? {
				var current: UIViewController? = probe
				while let parent = current?.parent {
					if let navigation = parent as? UINavigationController {
						return navigation
					}
					current = parent
				}
				return nil
			}

			private func makeTitleView() -> UIView {
				let frame = CGRect(x: 0, y: 0, width: parent.width, height: parent.height)
				if let privateClass = NSClassFromString("_UINavigationBarTitleView") as? UIView.Type,
				   privateClass.instancesRespond(to: #selector(UIView.init(frame:)))
				{
					let heightSelector = NSSelectorFromString("setHeight:")
					let hideSelector = NSSelectorFromString("setHideStandardTitle:")
					if scalarImplementation(on: privateClass, selector: heightSelector, argument: "d") != nil,
					   scalarImplementation(on: privateClass, selector: hideSelector, argument: "B") != nil
					{
						return privateClass.init(frame: frame)
					}
					logSetterFailure()
					return UIView(frame: CGRect(x: 0, y: 0, width: parent.width, height: 44))
				}
				logPrivateClassFailure()
				return UIView(frame: frame)
			}

			private func configure(titleView: UIView, navigation: UINavigationController) {
				// A content view hosts SwiftUI without putting a hosting controller under a mismatched parent.
				let contentView = hostedContentView ?? makeContentView()
				hostedContentView = contentView
				if contentView.superview !== titleView {
					widthConstraint?.isActive = false
					heightConstraint?.isActive = false
					contentView.translatesAutoresizingMaskIntoConstraints = false
					titleView.addSubview(contentView)
					let width = contentView.widthAnchor.constraint(equalToConstant: parent.width)
					let height = contentView.heightAnchor.constraint(equalToConstant: parent.height)
					widthConstraint = width
					heightConstraint = height
					NSLayoutConstraint.activate([
						contentView.topAnchor.constraint(equalTo: titleView.topAnchor),
						contentView.centerXAnchor.constraint(equalTo: titleView.centerXAnchor),
						width,
						height,
					])
				}
				contentView.configuration = makeConfiguration()
				widthConstraint?.constant = max(1, parent.width)
				heightConstraint?.constant = max(1, parent.height)
				titleView.frame.size.width = max(1, parent.width)
				let heightSelector = NSSelectorFromString("setHeight:")
				let hideSelector = NSSelectorFromString("setHideStandardTitle:")
				guard let heightMethod = scalarImplementation(on: titleView, selector: heightSelector, argument: "d"),
				      let hideMethod = scalarImplementation(on: titleView, selector: hideSelector, argument: "B")
				else {
					logSetterFailure()
					titleView.frame.size.height = 44
					heightConstraint?.constant = 44
					navigation.navigationBar.setNeedsLayout()
					return
				}
				typealias HeightSetter = @convention(c) (AnyObject, Selector, CGFloat) -> Void
				typealias HideSetter = @convention(c) (AnyObject, Selector, Bool) -> Void
				unsafeBitCast(heightMethod, to: HeightSetter.self)(titleView, heightSelector, max(1, parent.height))
				unsafeBitCast(hideMethod, to: HideSetter.self)(titleView, hideSelector, true)
				navigation.navigationBar.setNeedsLayout()
			}

			private func makeConfiguration() -> UIHostingConfiguration<Content, EmptyView> {
				let materializedContent = parent.content
				return UIHostingConfiguration {
					materializedContent
				}
				.margins(.all, 0)
			}

			private func makeContentView() -> UIView & UIContentView {
				makeConfiguration().makeContentView()
			}

			private func logPrivateClassFailure() {
				guard !didLogPrivateClassFailure else { return }
				didLogPrivateClassFailure = true
				print("[RichNavigationTitle] _UINavigationBarTitleView is unavailable or incompatible; using the standard 44-point title view.")
			}

			private func logSetterFailure() {
				guard !didLogSetterFailure else { return }
				didLogSetterFailure = true
				print("[RichNavigationTitle] private title height or standard-title setter is unavailable or incompatible; using the standard 44-point title view.")
			}

			private func scalarImplementation(on view: UIView, selector: Selector, argument: String) -> IMP? {
				guard view.responds(to: selector) else { return nil }
				return scalarImplementation(on: type(of: view), selector: selector, argument: argument)
			}

			private func scalarImplementation(on viewClass: UIView.Type, selector: Selector, argument: String) -> IMP? {
				guard let method = class_getInstanceMethod(viewClass, selector),
				      method_getNumberOfArguments(method) == 3,
				      let argumentType = method_copyArgumentType(method, 2) else { return nil }
				let resultType = method_copyReturnType(method)
				defer {
					free(resultType)
					free(argumentType)
				}
				guard String(cString: resultType) == "v",
				      String(cString: argumentType) == argument else { return nil }
				return method_getImplementation(method)
			}
		}
	}

	private extension UIViewController {
		func owningViewController(for navigation: UINavigationController) -> UIViewController? {
			var current: UIViewController? = self
			while let parent = current?.parent {
				if parent === navigation {
					return current
				}
				current = parent
			}
			return nil
		}
	}

	struct RichNavigationTitleDemo: View {
		var body: some View {
			NavigationLink {
				RichNavigationTitleDemoDetail()
			} label: {
				Label("Open profile detail", systemImage: "person.crop.circle")
			}
			.accessibilityIdentifier("rich-title-open-detail")
		}
	}

	private struct RichNavigationTitleDemoDetail: View {
		@State private var status = "Ready"

		var body: some View {
			List {
				Section("Status") {
					Text(status)
						.accessibilityLabel("Profile status: \(status)")
						.accessibilityIdentifier("rich-title-status")
				}
			}
			.navigationTitle("Profile")
			.richNavigationTitle(height: 84, width: 160) {
				VStack(spacing: 2) {
					Image(systemName: "person.crop.circle.fill")
						.font(.system(size: 44))
						.accessibilityHidden(true)
					Text("Seb Vidal")
						.font(.caption)
				}
				.accessibilityElement(children: .combine)
				.accessibilityLabel("Seb Vidal")
				.accessibilityIdentifier("rich-title-profile")
			}
			.toolbar {
				ToolbarItem(placement: .topBarTrailing) {
					Button {
						status = status == "Ready" ? "Updated" : "Ready"
					} label: {
						Label("Update status", systemImage: "arrow.triangle.2.circlepath")
					}
					.accessibilityIdentifier("rich-title-update-status")
				}
			}
		}
	}

	private struct RichNavigationTitleDemoPreview: PreviewProvider {
		static var previews: some View {
			NavigationStack {
				List {
					RichNavigationTitleDemo()
				}
				.navigationTitle("Profiles")
			}
		}
	}

	@available(iOS 26.0, *)
	struct LargeToolbarTitleDemo: View {
		var body: some View {
			List {
				Section("Examples") {
					Label("Toolbar content", systemImage: "textformat")
					Label("Large title treatment", systemImage: "rectangle.topthird.inset.filled")
				}
			}
			.navigationTitle("Toolbar Title")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .title) {
					VStack(spacing: 4) {
						Image(systemName: "person.crop.circle.fill")
							.font(.system(size: 56))
							.accessibilityHidden(true)
						Text("Toolbar title")
							.font(.title2.weight(.semibold))
					}
					.frame(width: 200, height: 110)
					.accessibilityElement(children: .combine)
					.accessibilityLabel("Large toolbar title")
					.accessibilityIdentifier("toolbar-title.large")
				}
			}
		}
	}
#endif
