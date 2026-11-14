//
//  AccessoryContextMenuDemo.swift
//  Ergo
//
//  Created by Adon Omeri on 8/11/2026.
//

#if os(iOS)
	import ObjectiveC.runtime
	import SwiftUI
	import UIKit

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
#endif
