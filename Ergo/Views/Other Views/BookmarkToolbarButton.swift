import Defaults
import SwiftUI

struct BookmarkToolbarButton: View {
	let reference: CatalogReference
	@Default(.bookmarks) private var bookmarks
	@Environment(CatalogStore.self) private var catalog

	private var isBookmarked: Bool {
		bookmarks.contains(reference)
	}

	var body: some View {
		Button {
			IntentDonations.bookmark(reference, added: !isBookmarked, catalog: catalog)

			withAnimation(.easeInOut) {
				if isBookmarked {
					bookmarks.remove(reference)
				} else {
					bookmarks.insert(reference)
				}
			}
		} label: {
			Label(
				isBookmarked ? "Remove Bookmark" : "Add Bookmark",
				systemImage: isBookmarked ? "bookmark.fill" : "bookmark"
			)
			.labelStyle(.iconOnly)
			.contentTransition(.symbolEffect(.replace))
		}
		.accessibilityLabel(isBookmarked ? "Remove Bookmark" : "Add Bookmark")
		.accessibilityIdentifier("bookmark.\(reference.category).\(reference.id)")
		.buttonStyle(.glassProminent)
		.tint(isBookmarked ? .accent : .clear)
	}
}
