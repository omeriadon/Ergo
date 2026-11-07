//
//  SourceReaderSheet.swift
//  Ergo
//
//  Created by Adon Omeri on 7/11/2026.
//

import ErgoLogic
import SwiftUI

/// A source on a board this person can only view: what it says, with nothing to change
struct SourceReaderSheet: View {
	let source: BoardSource

	@Environment(\.dismiss)
	private var dismiss

	private var text: String {
		switch source.content {
			case let .text(text):
				text
			case let .link(url, title):
				[title, url.absoluteString].compactMap(\.self).joined(separator: "\n\n")
		}
	}

	var body: some View {
		NavigationStack {
			ScrollView {
				Text(text)
					.textSelection(.enabled)
					.frame(maxWidth: .infinity, alignment: .leading)
					.padding(.horizontal, 20)
					.accessibilityIdentifier("source.reader")
			}
			.navigationTitle(source.link == nil ? "Text" : "Web Link")
			.toolbarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .topBarTrailing) {
					Button(role: .close) {
						dismiss()
					}
					.accessibilityIdentifier("source.reader.close")
				}
			}
		}
		.presentationDragIndicator(.visible)
	}
}

#Preview {
	SourceReaderSheet(source: BoardSource(position: .zero, content: .text("All men are mortal, and Socrates is a man.")))
}
