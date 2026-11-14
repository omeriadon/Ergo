//
//  Attachments.swift
//  Ergo
//

import SwiftUI

/// What's going with a message, as a row of folded sheets. `remove` and `update` are only there until it's sent.
struct AskAttachmentsRow: View {
	let attachments: [AskAttachment]
	var remove: ((AskAttachment.ID) -> Void)?
	var update: ((AskAttachment.ID, String) -> Void)?

	var body: some View {
		AskAttachmentOpener(update: update, remove: remove) { open in
			ScrollView(.horizontal) {
				HStack(spacing: 8) {
					ForEach(attachments) { attachment in
						AskAttachmentTile(
							attachment: attachment,
							open: { open(attachment) },
							remove: remove.map { remove in { remove(attachment.id) } }
						)
						.transition(.blurReplace)
					}
				}
			}
			.scrollIndicators(.hidden)
			.scrollClipDisabled()
		}
	}
}

/// Everything a chat has been given, three to a row. Each opens as it does above the composer.
struct AskAttachmentsSheet: View {
	private static let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

	let conversation: AskConversation

	/// For a sheet underneath this one, which would stay on top of the library too
	var leaving: () -> Void = {}

	@Environment(\.dismiss)
	private var dismiss

	var body: some View {
		NavigationStack {
			AskAttachmentOpener(leaving: { dismiss(); leaving() }) { open in
				ScrollView {
					LazyVGrid(columns: Self.columns, spacing: 12) {
						ForEach(conversation.sentAttachments) { attachment in
							AskAttachmentTile(attachment: attachment, side: nil, open: { open(attachment) }, remove: nil)
						}
					}
					.padding()
				}
			}
			.navigationTitle("Attachments")
			.toolbarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .sheetDismissal) {
					Button(role: .close) {
						dismiss()
					}
					.accessibilityIdentifier("ask.attachments.close")
				}
			}
		}
		.presentationDetents([.medium, .large])
	}
}

// MARK: - Opening

/// Opens what's tapped: a library entry on its tab, a link in the browser, and text in a sheet
private struct AskAttachmentOpener<Content: View>: View {
	var update: ((AskAttachment.ID, String) -> Void)?
	var remove: ((AskAttachment.ID) -> Void)?

	/// A sheet showing the tiles would otherwise stay on top of the library
	var leaving: () -> Void = {}

	@ViewBuilder let content: (@escaping (AskAttachment) -> Void) -> Content

	@Environment(NavigationManager.self)
	private var navigation

	@Environment(\.openURL)
	private var openURL

	/// The text being read or edited
	@State private var opened: AskAttachment?

	var body: some View {
		content(open)
			.sheet(item: $opened) { attachment in
				AskAttachmentTextSheet(attachment: attachment, update: update, remove: remove)
			}
	}

	private func open(_ attachment: AskAttachment) {
		switch attachment.content {
			case let .library(reference):
				leaving()
				navigation.openLibraryEntry(category: reference.category, id: reference.id)
			case .text:
				opened = attachment
			case let .link(url, _, _):
				openURL(url)
		}
	}
}

// MARK: - The tile

private struct AskAttachmentTile: View {
	private static let shape = FoldedSheet(corner: 12, fold: 14)

	let attachment: AskAttachment

	/// Nil takes the width it's given, as a square
	var side: CGFloat? = 76
	let open: () -> Void
	let remove: (() -> Void)?

	private var tint: Color {
		switch attachment.content {
			case let .library(reference):
				reference.category.themeColor
			case .link:
				.accent
			case .text:
				.secondary
		}
	}

	var body: some View {
		Button(action: open) {
			content
				.frame(width: side, height: side)
				.aspectRatio(1, contentMode: .fit)
				// A fixed size, like a box on the canvas, so the type can't grow out of it
				.dynamicTypeSize(...DynamicTypeSize.large)
				.background(tint.opacity(0.12), in: Self.shape)
				.background(.ultraThinMaterial, in: Self.shape)
				.overlay { Self.shape.stroke(tint.opacity(0.5), lineWidth: 1) }
				.overlay(alignment: .topTrailing) {
					FoldFlap(fold: Self.shape.fold)
						.fill(tint.opacity(0.35))
						.frame(width: Self.shape.fold, height: Self.shape.fold)
				}
				.contentShape(Self.shape)
		}
		.buttonStyle(.plain)
		.accessibilityLabel(attachment.title)
		.accessibilityIdentifier("ask.attachment.\(attachment.id.uuidString)")
		.overlay(alignment: .topLeading) {
			if let remove {
				removeButton(remove)
			}
		}
	}

	@ViewBuilder
	private var content: some View {
		switch attachment.content {
			case let .library(reference):
				symbol(reference.category.symbol, title: reference.name)

			case .link:
				symbol("link", title: attachment.displayURL ?? "")

			case let .text(text):
				Text(text)
					.font(.caption2.scaled(by: 0.6))
					.padding(6)
					.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
		}
	}

	private func symbol(_ name: String, title: String) -> some View {
		VStack(spacing: 2) {
			Image(systemName: name)
				.font(.title2)
				.foregroundStyle(tint)
				.frame(maxHeight: .infinity)

			Text(title)
				.font(.caption)
				.lineLimit(1)
				.padding(.horizontal, 6)
		}
		.padding(.bottom, 6)
	}

	private func removeButton(_ remove: @escaping () -> Void) -> some View {
		Button("Remove", systemImage: "xmark", action: remove)
			.labelStyle(.iconOnly)
			.font(.caption2.weight(.bold))
			.imageScale(.small)
			.foregroundStyle(.secondary)
			.buttonStyle(.plain)
			.frame(width: 18, height: 18)
			.background(.regularMaterial, in: .circle)
			.padding(4)
			.contentShape(Rectangle())
			.accessibilityLabel("Remove \(attachment.title)")
			.accessibilityIdentifier("ask.attachment.remove.\(attachment.id.uuidString)")
	}
}

// MARK: - Editing text

private struct AskAttachmentTextSheet: View {
	let attachment: AskAttachment
	let update: ((AskAttachment.ID, String) -> Void)?
	let remove: ((AskAttachment.ID) -> Void)?

	@Environment(\.dismiss)
	private var dismiss

	@State private var text: String

	init(
		attachment: AskAttachment,
		update: ((AskAttachment.ID, String) -> Void)?,
		remove: ((AskAttachment.ID) -> Void)?
	) {
		self.attachment = attachment
		self.update = update
		self.remove = remove
		_text = State(initialValue: attachment.plainText ?? "")
	}

	var body: some View {
		NavigationStack {
			ScrollView {
				field
					.padding()
					.frame(maxWidth: .infinity, alignment: .leading)
			}
			.toolbar {
				ToolbarItem(placement: .sheetDismissal) {
					Button(role: .close) {
						dismiss()
					}
					.accessibilityIdentifier("ask.attachment.close")
				}
			}
		}
		.presentationDetents([.medium, .large])
		// Nothing left to send
		.onDisappear {
			if text.trimmedNonEmpty == nil {
				remove?(attachment.id)
			}
		}
	}

	@ViewBuilder
	private var field: some View {
		if let update {
			TextField("Text", text: $text, axis: .vertical)
				.onChange(of: text) {
					update(attachment.id, text)
				}
				.accessibilityIdentifier("ask.attachment.text")
		} else {
			Text(text)
				.textSelection(.enabled)
		}
	}
}
