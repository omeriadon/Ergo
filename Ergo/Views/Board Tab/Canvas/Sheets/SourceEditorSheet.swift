//
//  SourceEditorSheet.swift
//  Ergo
//
//  Created by Adon Omeri on 7/11/2026.
//

import ErgoShare
import SwiftUI

/// Writing a block of text or a web link, new or already on the board. What happens with it is the canvas's business.
struct SourceEditorSheet: View {
	enum Kind {
		case text
		case link
	}

	let kind: Kind
	let save: (BoardSource.Content) -> Void

	@Environment(\.dismiss)
	private var dismiss

	@State private var text: String
	@State private var title: String
	@State private var problem: String?
	@FocusState private var focused: Bool

	init(kind: Kind, content: BoardSource.Content? = nil, save: @escaping (BoardSource.Content) -> Void) {
		self.kind = kind
		self.save = save
		switch content {
			case let .text(text):
				_text = State(initialValue: text)
				_title = State(initialValue: "")
			case let .link(url, title):
				_text = State(initialValue: url.absoluteString)
				_title = State(initialValue: title ?? "")
			case nil:
				_text = State(initialValue: "")
				_title = State(initialValue: "")
		}
	}

	private var isBlank: Bool {
		text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
	}

	var body: some View {
		NavigationStack {
			Group {
				switch kind {
					case .text: textEditor
					case .link: linkForm
				}
			}
			.navigationTitle(kind == .text ? "Text" : "Web Link")
			.toolbarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .topBarLeading) {
					Button(role: .cancel) {
						dismiss()
					}
					.accessibilityIdentifier("source.cancel")
				}

				ToolbarItem(placement: .topBarTrailing) {
					Button(role: .confirm, action: finish)
						.disabled(isBlank)
						.accessibilityIdentifier("source.save")
				}
			}
			.onAppear {
				focused = true
			}
		}
		.presentationDragIndicator(.visible)
	}

	private var textEditor: some View {
		TextEditor(text: $text)
			.textEditorStyle(.plain)
			.focused($focused)
			.padding(.horizontal, 15)
			.accessibilityLabel("Text")
			.accessibilityIdentifier("source.text")
	}

	private var linkForm: some View {
		Form {
			Section {
				TextField("example.com/article", text: $text)
					.keyboardType(.URL)
					.textContentType(.URL)
					.textInputAutocapitalization(.never)
					.autocorrectionDisabled()
					.focused($focused)
					.accessibilityIdentifier("source.link")
			} footer: {
				if let problem {
					Text(problem)
						.foregroundStyle(.red)
				} else {
					Text("Opens in your browser.")
				}
			}

			Section("Title") {
				TextField("Found from the page", text: $title)
					.accessibilityIdentifier("source.title")
			}
		}
	}

	private func finish() {
		switch kind {
			case .text:
				save(.text(text.trimmingCharacters(in: .whitespacesAndNewlines)))

			case .link:
				guard let url = Self.webLink(from: text) else {
					problem = "Expected a web link, found '\(text.trimmingCharacters(in: .whitespacesAndNewlines))'"
					return
				}
				let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
				save(.link(url, title: title.isEmpty ? nil : title))
		}
		dismiss()
	}

	/// People leave the https:// off. Only web links get through, since they're what the browser can open.
	private static func webLink(from text: String) -> URL? {
		let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !text.contains(where: \.isWhitespace) else { return nil }

		let hasScheme = text.lowercased().hasPrefix("http://") || text.lowercased().hasPrefix("https://")
		guard let url = URL(string: hasScheme ? text : "https://\(text)"), url.isWebLink, url.host()?.contains(".") == true else { return nil }
		return url
	}
}
