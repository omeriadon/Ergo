//
//  CustomAlertBridge.swift
//  Ergo
//
//  Created by Adon Omeri on 8/11/2026.
//

import SwiftUI

#if os(iOS)
	import UIKit

	struct CustomAlertBridge<Content: View, Header: View>: UIViewControllerRepresentable {
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
	}
#endif
