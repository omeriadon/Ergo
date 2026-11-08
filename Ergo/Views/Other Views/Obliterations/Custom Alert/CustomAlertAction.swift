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
	final class CustomAlertController: UIAlertController {
		var didDisappear: (() -> Void)?

		override func viewDidDisappear(_ animated: Bool) {
			super.viewDidDisappear(animated)
			didDisappear?()
		}
	}

	@MainActor
	final class CustomAlertPresenter: UIViewController {
		var update: (() -> Void)?

		override func viewDidAppear(_ animated: Bool) {
			super.viewDidAppear(animated)
			update?()
		}
	}
#endif
