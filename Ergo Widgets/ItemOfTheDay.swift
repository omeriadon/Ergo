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

	@Environment(\.widgetFamily) var widgetFamily

	var body: some View {
		VStack(alignment: .leading, spacing: 2) {
			Group {
				switch entry.item {
					case nil:
						Text("Open Ergo")
					case let .argument(argument):
						Text(argument.name)
					case let .bias(bias):
						Text(bias.name)
					case let .concept(concept):
						Text(concept.name)
					case let .fallacy(fallacy):
						Text(fallacy.name)
					case let .paradox(paradox):
						Text(paradox.name)
					case let .philosopher(philosopher):
						Text(philosopher.name)
					case let .razor(razor):
						Text(razor.name)
				}
			}
			.padding(.bottom, 5)
			.font(widgetFamily != .systemLarge ? .callout : .title3)
			.bold()

			Spacer(minLength: 1)

			Group {
				if widgetFamily == .systemSmall {
					switch entry.item {
						case nil:
							Text("Open Ergo")
						case let .argument(argument):
							Text(argument.summary)
						case let .bias(bias):
							Text(bias.summary)
						case let .concept(concept):
							Text(concept.summary)
						case let .fallacy(fallacy):
							Text(fallacy.summary)
						case let .paradox(paradox):
							Text(paradox.summary)
						case let .philosopher(philosopher):
							Text(philosopher.summary)
						case let .razor(razor):
							Text(razor.summary)
					}

				} else {
					switch entry.item {
						case nil:
							Text("Open Ergo")
						case let .argument(argument):
							Text(argument.body)
						case let .bias(bias):
							Text(bias.body)
						case let .concept(concept):
							Text(concept.body)
						case let .fallacy(fallacy):
							Text(fallacy.body)
						case let .paradox(paradox):
							Text(paradox.body)
						case let .philosopher(philosopher):
							Text(philosopher.body)
						case let .razor(razor):
							Text(razor.body)
					}
				}
			}
			.padding(.bottom, 10)
			.font(widgetFamily == .systemSmall ? .caption2 : widgetFamily == .systemMedium ? .footnote : .caption)

			if widgetFamily != .systemSmall, widgetFamily != .systemMedium {
				Spacer(minLength: 1)
				Spacer(minLength: 1)
			}

			if widgetFamily != .systemSmall, widgetFamily != .systemMedium {
				let examples: [Example] = switch entry.item {
					case nil:
						[]
					case let .argument(argument):
						argument.examples
					case let .bias(bias):
						bias.examples
					case let .concept(concept):
						concept.examples
					case let .fallacy(fallacy):
						fallacy.examples
					case let .paradox(paradox):
						paradox.examples
					case .philosopher:
						[]
					case let .razor(razor):
						razor.examples
				}

				if !examples.isEmpty {
					Text("Examples")
						.foregroundStyle(.secondary)
						.textCase(.uppercase)
						.font(.caption)

					VStack(alignment: .leading, spacing: 4) {
						ForEach(examples, id: \.text) { example in
							Text("-  \(example.text)")
								.textSelection(.enabled)
							if let note = example.note {
								Text("-  \(note)")
									.textSelection(.enabled)
									.padding(.leading, 30)
							}
						}
					}
					.font(.footnote)
				}
			}
		}
	}
}

// MARK: - Background

struct ItemOfTheDayBackground: View {
	@Environment(\.widgetFamily) var family

	/// Nil when the library couldn't be read
	let category: LibraryContent?

	var body: some View {
		let background = switch family {
			case .systemSmall: "small_blur"
			case .systemMedium: "medium_blur"
			case .systemLarge: "large_blur"
			default: "large_blur"
		}

		Image(background)
			.renderingMode(.template)
			.resizable()
			.scaledToFill()
			.foregroundStyle(category?.themeColor ?? .accent)
	}
}

// MARK: - Widget

struct ItemOfTheDayWidget: Widget {
	let kind: String = "ItemOfTheDayWidget"

	var body: some WidgetConfiguration {
		StaticConfiguration(kind: kind, provider: ItemOfTheDayProvider()) { entry in
			ItemOfTheDayWidgetView(entry: entry)
				.widgetURL(entry.url)
				.fontDesign(.rounded)
				.containerBackground(for: .widget) {
					ItemOfTheDayBackground(category: entry.reference?.category)
				}
		}
		.containerBackgroundRemovable(true)
		.configurationDisplayName("Item Of The Day")
		.description("See the item of the day, filter them in settings.")
		.supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
	}
}
