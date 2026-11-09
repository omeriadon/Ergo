//
//  Toolbar+.swift
//  Ergo
//
//  Created by Adon Omeri on 1/11/2026.
//

import SwiftUI

extension View {
	func toolbarTitleItem() -> some View {
		modifier(ToolbarTitleItemModifier())
	}
}

private struct ToolbarTitleItemModifier: ViewModifier {
	@Environment(NavigationManager.self) private var navigation

	func body(content: Content) -> some View {
		content
			.toolbar {
				ToolbarTitleItem(
					openSettings: {
						navigation.presentSheet(.settings(id: "3refd"))
					}
				)
			}
	}
}

struct ToolbarTitleItem: ToolbarContent {
	let openSettings: () -> Void

	var body: some ToolbarContent {
		ToolbarItem(placement: .topBarLeading) {
			Button {
				openSettings()
			} label: {
				ToolbarTitleView()
			}
		}
		.visibilityPriority(.high)
		.sharedBackgroundVisibility(.hidden)
	}
}

struct ToolbarTitleView: View {
	var body: some View {
		Image("Ergo")
			.foregroundStyle(.accent)
	}
}

extension View {
	func toolbarTitleVire(_ title: String, _ symbol: String) -> some View {
		modifier(ToolbarTitleViewModifier(title: title, symbol: symbol))
	}
}

private struct ToolbarTitleViewModifier: ViewModifier {
	@Environment(NavigationManager.self) private var navigation

	let title: String
	let symbol: String

	func body(content: Content) -> some View {
		content
			.navigationTitle(title)
			.navigationBarTitleDisplayMode(.inline)
			.scrollEdgeEffectStyle(.soft, for: .all)
			.toolbar {
				ToolbarItem(placement: .title) {
					Label {
						Text(title)
					} icon: {
						if symbol.isEmpty {
							EmptyView()
						} else {
							Image(systemName: symbol)
								.foregroundStyle(.accent)
						}
					}
					.labelStyle(.titleAndIcon)
				}
			}
	}
}

extension View {
	/// A title that fades in under the navigation bar once the page has scrolled.
	func libraryDetailTitle(_ name: String, category: String, hasScrolled: Bool) -> some View {
		modifier(LibraryDetailTitleModifier(name: name, category: category, hasScrolled: hasScrolled))
	}
}

private struct LibraryDetailTitleModifier: ViewModifier {
	let name: String
	let category: String
	let hasScrolled: Bool

	@State private var containerWidth: CGFloat = 0
	@State private var nameHeight: CGFloat = 0
	@State private var lineHeight: CGFloat = 0

	/// Three lines of text (a two-line name and the category). Fixed, so the bar never changes height once the page is shown.
	@ScaledMetric(relativeTo: .body) private var height: CGFloat = 66

	/// Until the name has been measured, it's laid out as if it were two lines.
	private var isOneLine: Bool {
		nameHeight > 0 && lineHeight > 0 && nameHeight <= lineHeight * 1.5
	}

	func body(content: Content) -> some View {
		content
			.onGeometryChange(for: CGFloat.self) {
				$0.size.width
			} action: {
				containerWidth = $0
			}
			.richNavigationTitle(height: height, width: containerWidth * 0.7) {
				VStack {
					if isOneLine {
						Spacer(minLength: 0)
							.frame(height: 5)

						titleLines

						Spacer(minLength: 0)
					} else {
						Spacer(minLength: 0)

						titleLines

						Spacer(minLength: 0)
						Spacer(minLength: 0)
					}
				}
				.contentTransition(.numericText())
				.animation(.easeInOut(duration: 0.2), value: hasScrolled)
			}
	}

	private var titleLines: some View {
		VStack {
			Text(name)
				.lineLimit(2)
				.multilineTextAlignment(.center)
				.opacity(hasScrolled ? 1 : 0)
				.onGeometryChange(for: CGFloat.self) {
					$0.size.height
				} action: {
					nameHeight = $0
				}
				.background {
					// Single-line reference using the same font.
					Text("Ag")
						.fixedSize()
						.hidden()
						.onGeometryChange(for: CGFloat.self) {
							$0.size.height
						} action: {
							lineHeight = $0
						}
				}

			Text(hasScrolled ? category : "")
				.textCase(.uppercase)
				.font(.caption2)
				.foregroundStyle(.secondary)
		}
	}
}
