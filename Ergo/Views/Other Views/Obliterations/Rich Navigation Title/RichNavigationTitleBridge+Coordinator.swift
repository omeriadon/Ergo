//
//  RichNavigationTitleBridge+Coordinator.swift
//  Ergo
//
//  Created by Adon Omeri on 8/11/2026.
//

import SwiftUI

#if os(iOS)
	import ObjectiveC
	import UIKit

	extension RichNavigationTitleBridge {
		@MainActor
		final class Coordinator: NSObject {
			var parent: RichNavigationTitleBridge
			weak var navigationController: UINavigationController?
			weak var installedTitleView: UIView?
			weak var navigationItem: UINavigationItem?
			var hostedContentView: (any UIView & UIContentView)?
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

			func titleWillAppear(for probe: ProbeViewController, transition: any UIViewControllerTransitionCoordinator?) {
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
			func fadeTitle(to alpha: CGFloat, transition: any UIViewControllerTransitionCoordinator?) {
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

			func findNavigationController(from probe: UIViewController) -> UINavigationController? {
				var current: UIViewController? = probe
				while let parent = current?.parent {
					if let navigation = parent as? UINavigationController {
						return navigation
					}
					current = parent
				}
				return nil
			}

			func makeTitleView() -> UIView {
				let frame = CGRect(x: 0, y: 0, width: parent.width, height: parent.height)
				if let privateClass = NSClassFromString("_UINavigationBarTitleView") as? UIView.Type,
				   privateClass.instancesRespond(to: #selector(UIView.init(frame:)))
				{
					let heightSelector = NSSelectorFromString("setHeight:")
					let hideSelector = NSSelectorFromString("setHideStandardTitle:")
					if unsafe scalarImplementation(on: privateClass, selector: heightSelector, argument: "d") != nil,
					   unsafe scalarImplementation(on: privateClass, selector: hideSelector, argument: "B") != nil
					{
						return privateClass.init(frame: frame)
					}
					logSetterFailure()
					return UIView(frame: CGRect(x: 0, y: 0, width: parent.width, height: 44))
				}
				logPrivateClassFailure()
				return UIView(frame: frame)
			}

			func configure(titleView: UIView, navigation: UINavigationController) {
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
				guard let heightMethod = unsafe scalarImplementation(on: titleView, selector: heightSelector, argument: "d"),
				      let hideMethod = unsafe scalarImplementation(on: titleView, selector: hideSelector, argument: "B")
				else {
					logSetterFailure()
					titleView.frame.size.height = 44
					heightConstraint?.constant = 44
					navigation.navigationBar.setNeedsLayout()
					return
				}
				typealias HeightSetter = @convention(c) (AnyObject, Selector, CGFloat) -> Void
				typealias HideSetter = @convention(c) (AnyObject, Selector, Bool) -> Void
				unsafe unsafeBitCast(heightMethod, to: HeightSetter.self)(titleView, heightSelector, max(1, parent.height))
				unsafe unsafeBitCast(hideMethod, to: HideSetter.self)(titleView, hideSelector, true)
				navigation.navigationBar.setNeedsLayout()
			}

			func makeConfiguration() -> UIHostingConfiguration<Content, EmptyView> {
				let materializedContent = parent.content
				return UIHostingConfiguration {
					materializedContent
				}
				.margins(.all, 0)
			}

			func makeContentView() -> any UIView & UIContentView {
				makeConfiguration().makeContentView()
			}

			func logPrivateClassFailure() {
				guard !didLogPrivateClassFailure else { return }
				didLogPrivateClassFailure = true
				print("[RichNavigationTitle] _UINavigationBarTitleView is unavailable or incompatible; using the standard 44-point title view.")
			}

			func logSetterFailure() {
				guard !didLogSetterFailure else { return }
				didLogSetterFailure = true
				print("[RichNavigationTitle] private title height or standard-title setter is unavailable or incompatible; using the standard 44-point title view.")
			}

			func scalarImplementation(on view: UIView, selector: Selector, argument: String) -> IMP? {
				guard view.responds(to: selector) else { return nil }
				return unsafe scalarImplementation(on: type(of: view), selector: selector, argument: argument)
			}

			func scalarImplementation(on viewClass: UIView.Type, selector: Selector, argument: String) -> IMP? {
				guard let method = unsafe class_getInstanceMethod(viewClass, selector),
				      unsafe method_getNumberOfArguments(method) == 3,
				      let argumentType = unsafe method_copyArgumentType(method, 2) else { return nil }
				let resultType = unsafe method_copyReturnType(method)
				defer {
					unsafe free(resultType)
					unsafe free(argumentType)
				}
				guard unsafe String(cString: resultType) == "v",
				      unsafe String(cString: argumentType) == argument else { return nil }
				return unsafe method_getImplementation(method)
			}
		}
	}

	extension UIViewController {
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
#endif
