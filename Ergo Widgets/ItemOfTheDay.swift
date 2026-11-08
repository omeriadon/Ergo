//
//  ItemOfTheDay.swift
//  Ergo Widgets
//
//  Created by Adon Omeri on 8/11/2026.
//

import Defaults
import ErgoCatalog
import SwiftUI
import WidgetKit

struct DayEntry: TimelineEntry {
	let date: Date
	/// Nil only if the library couldn't be read
	let item: ItemOfTheDayItem?

	var reference: CatalogReference? {
		item?.reference
	}

	/// What tapping the widget opens in the app
	var url: URL? {
		item?.url
	}
}

// MARK: - Provider

/// All the choosing happens here: the view is given the item whole and only draws it.
struct ItemOfTheDayProvider: TimelineProvider {
	/// Set in Settings → Widgets. Empty means every kind.
	private var filter: Set<String> {
		Set(Defaults[.itemOfTheDayCategories])
	}

	func placeholder(in _: Context) -> DayEntry {
		entry(on: .now, id: ItemOfTheDay.pinned.first, index: try? CatalogStore.makeIndex())
	}

	func getSnapshot(in _: Context, completion: @escaping (DayEntry) -> Void) {
		completion(entries(days: 1).first ?? DayEntry(date: .now, item: nil))
	}

	func getTimeline(in _: Context, completion: @escaping (Timeline<DayEntry>) -> Void) {
		// A week of midnights, each already known, so the widget changes on time even if it isn't woken
		completion(Timeline(entries: entries(days: 7), policy: .atEnd))
	}

	/// The items for today and the days after, filtered by the setting
	func entries(days: Int) -> [DayEntry] {
		let calendar = Calendar.current
		let today = calendar.startOfDay(for: .now)
		let filter = filter
		let index = try? CatalogStore.makeIndex()

		return (0 ..< days).compactMap { offset in
			guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { return nil }
			return entry(on: day, id: ItemOfTheDay.entry(on: day, categories: filter), index: index)
		}
	}

	private func entry(on date: Date, id: String?, index: CatalogIndex?) -> DayEntry {
		let item = id.flatMap { id in index.flatMap { ItemOfTheDayItem.load(id, index: $0) } }
		return DayEntry(date: date, item: item)
	}
}

// MARK: - View

struct ItemOfTheDayWidgetView: View {
	var entry: ItemOfTheDayProvider.Entry

	var body: some View {
		VStack(alignment: .leading) {}
			.padding()
	}
}

// MARK: - Widget

struct ItemOfTheDayWidget: Widget {
	let kind: String = "ItemOfTheDayWidget"

	var body: some WidgetConfiguration {
		StaticConfiguration(kind: kind, provider: ItemOfTheDayProvider()) { entry in
			ItemOfTheDayWidgetView(entry: entry)
				.widgetURL(entry.url)
				.containerBackground(for: .widget) {
					Image("small_blur")
						.renderingMode(.template)
						.resizable()
						.scaledToFill()
				}
		}
		.containerBackgroundRemovable(true)
		.configurationDisplayName("Item Of The Day")
		.description("See the item of the day, filter them in settings.")
		.supportedFamilies([.systemSmall])
	}
}
