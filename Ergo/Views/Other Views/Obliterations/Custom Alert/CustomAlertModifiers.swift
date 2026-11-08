//
//  CustomAlertModifiers.swift
//  Ergo
//
//  Created by Adon Omeri on 8/11/2026.
//

import SwiftUI

#if os(iOS)
	import UIKit

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
#endif
