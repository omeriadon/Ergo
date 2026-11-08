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

	struct RichNavigationTitleBridge<Content: View>: UIViewControllerRepresentable {
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
	}

	extension RichNavigationTitleBridge {
		@MainActor
		final class ProbeViewController: UIViewController {
			var onAttachment: (() -> Void)?
			var onWillAppear: ((any UIViewControllerTransitionCoordinator?) -> Void)?
			var onDidAppear: (() -> Void)?
			var onWillDisappear: ((any UIViewControllerTransitionCoordinator?) -> Void)?
			var canInstall = false

			var activeTransition: any UIViewControllerTransitionCoordinator? {
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
	}
#endif
