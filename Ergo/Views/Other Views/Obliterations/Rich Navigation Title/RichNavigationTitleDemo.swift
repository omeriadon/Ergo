//
//  RichNavigationTitleDemo.swift
//  Ergo
//
//  Created by Adon Omeri on 8/11/2026.
//

import SwiftUI

#if os(iOS)
	import ObjectiveC
	import UIKit

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
