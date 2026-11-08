//
//  WidgetsSettingsView.swift
//  Ergo
//
//  Created by Adon Omeri on 8/11/2026.
//

import Defaults
import ErgoCatalog
import SwiftUI
import WidgetKit

struct WidgetsSettingsView: View {
	@Default(.itemOfTheDayCategories) var selected

	var body: some View {
		List {
			Section {
				ForEach(ItemOfTheDay.categories, id: \.self) { category in
					Toggle(Self.name(of: category), isOn: binding(for: category))
						.onChange(of: binding(for: category).wrappedValue) {
							WidgetCenter.shared.reloadTimelines(ofKind: "ItemOfTheDayWidget")
						}
				}
			} header: {
				Text("Item of the Day")
			} footer: {
				Text("Everyone gets the same item each day. Choosing fewer kinds narrows the same list down, so it never reshuffles. Choosing none shows every kind.")
			}
		}
		.toolbarTitleVire("Widgets", "widget.small")
	}

	private func binding(for category: String) -> Binding<Bool> {
		Binding {
			selected.isEmpty || selected.contains(category)
		} set: { isOn in
			var categories = selected.isEmpty ? Set(ItemOfTheDay.categories) : Set(selected)
			if isOn {
				categories.insert(category)
			} else if categories.count > 1 {
				categories.remove(category)
			}
			ItemOfTheDayStore.setCategories(categories)
		}
	}

	private static func name(of category: String) -> String {
		switch category {
			case "biases": "Biases"
			case "concepts": "Concepts"
			case "fallacies": "Fallacies"
			case "paradoxes": "Paradoxes"
			case "philosophers": "Philosophers"
			case "razors": "Razors"
			case "arguments": "Arguments"
			default: category.capitalized
		}
	}
}
