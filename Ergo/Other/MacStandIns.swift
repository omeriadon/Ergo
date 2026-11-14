//
//  MacStandIns.swift
//  Ergo
//

#if os(macOS)
	import SwiftUI

	// Mac versions of the iOS-only SwiftUI names the shared views use, so each call site reads the same on both. Each one
	// is the nearest Mac meaning, or nothing where the Mac has no such thing. SwiftUI's own unavailable versions lose to these.

	extension ToolbarItemPlacement {
		static let topBarLeading = ToolbarItemPlacement.navigation
		static let topBarTrailing = ToolbarItemPlacement.primaryAction
		static let title = ToolbarItemPlacement.principal
	}

	extension ToolbarPlacement {
		/// The window's toolbar is the Mac's navigation bar
		static let navigationBar = ToolbarPlacement.windowToolbar
	}

	extension ToolbarMinimizationBehavior {
		static let never = ToolbarMinimizationBehavior.automatic
	}

	extension MenuActionDismissBehavior {
		/// A Mac menu closes once something in it is chosen
		static let disabled = MenuActionDismissBehavior.automatic
	}

	extension ContentShapeKinds {
		/// The Mac's context menu has no lifted preview to shape
		static let contextMenuPreview: ContentShapeKinds = []
	}

	extension ContainerBackgroundPlacement {
		static let navigation = ContainerBackgroundPlacement.window
	}

	enum MacSearchDrawerDisplayMode {
		case always, automatic
	}

	extension SearchFieldPlacement {
		static func navigationBarDrawer(displayMode _: MacSearchDrawerDisplayMode) -> SearchFieldPlacement {
			.automatic
		}
	}

	/// The toolbar's overflow menu, as a plain menu at its end
	struct ToolbarOverflowMenu<Content: View>: ToolbarContent {
		private let content: Content

		init(@ViewBuilder content: () -> Content) {
			self.content = content()
		}

		var body: some ToolbarContent {
			ToolbarItem(placement: .primaryAction) {
				Menu("More", systemImage: "ellipsis.circle") {
					content
				}
			}
		}
	}

	enum MacTitleDisplayMode {
		case automatic, inline, large
	}

	enum MacTextInputAutocapitalization {
		case never, words, sentences, characters
	}

	enum MacKeyboardType {
		case `default`, URL, emailAddress, numberPad, asciiCapable
	}

	extension View {
		func navigationBarTitleDisplayMode(_: MacTitleDisplayMode) -> some View {
			self
		}

		func textInputAutocapitalization(_: MacTextInputAutocapitalization?) -> some View {
			self
		}

		func keyboardType(_: MacKeyboardType) -> some View {
			self
		}

		func listSectionIndexVisibility(_: Visibility) -> some View {
			self
		}
	}
#endif
