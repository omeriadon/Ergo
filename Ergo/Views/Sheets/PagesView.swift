//
//  PagesView.swift
//  Ergo
//
//  Created by Adon Omeri on 5/11/2026.
//

import Defaults
import ErgoLogic
import SwiftUI

struct PagesSheet: View {
	@Environment(NavigationManager.self)
	private var navigation

	@Environment(PageStore.self)
	private var pageStore

	@Default(.logicLetters) var logicLetters

	private var letters: [String] {
		LogicLetters.resolved(logicLetters)
	}

	var body: some View {
		NavigationStack {
			List {
				ForEach(pageStore.sortedPages) { page in
					Button {
						pageStore.open(page.id)
						navigation.dismissSheet()
					} label: {
						PageRow(
							page: page,
							letters: letters,
							isCurrent: page.id == pageStore.current.id
						)
					}
					.buttonStyle(.plain)
					.swipeActions {
						Button("Delete", systemImage: "trash", role: .destructive) {
							pageStore.delete([page.id])
						}
					}
				}
			}
			.overlay {
				if pageStore.pages.isEmpty {
					ContentUnavailableView(
						"No Pages",
						systemImage: "doc.text",
						description: Text("Anything you write on the Check tab is kept here.")
					)
				}
			}
			.navigationTitle("Pages")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .topBarLeading) {
					Button(role: .close) {
						navigation.dismissSheet()
					}
				}

				ToolbarItem(placement: .topBarTrailing) {
					Button("New Page", systemImage: "square.and.pencil") {
						pageStore.newPage()
						navigation.dismissSheet()
					}
					.accessibilityIdentifier("pages.newPage")
				}
			}
		}
	}
}

private struct PageRow: View {
	let page: LogicPage
	let letters: [String]
	let isCurrent: Bool

	var body: some View {
		HStack {
			VStack(alignment: .leading, spacing: 4) {
				Text(page.title(letters: letters))
					.font(.headline)
					.lineLimit(1)

				Text(page.modified, format: .relative(presentation: .named))
					.font(.subheadline)
					.foregroundStyle(.secondary)
			}

			Spacer(minLength: 0)

			if isCurrent {
				Image(systemName: "checkmark")
					.foregroundStyle(.tint)
					.accessibilityLabel("Open")
			}
		}
		.contentShape(Rectangle())
	}
}
