//
//  CanvasBar.swift
//  Ergo
//
//  Created by Adon Omeri on 6/11/2026.
//

import SwiftUI

/// What the floating bar offers, which depends on what is selected
enum CanvasBarMode: Equatable {
	case idle
	case statement
	case link

	/// A source, which a link's button opens in the browser rather than editing
	case source(isLink: Bool)

	/// Waiting for a box to be tapped, with what to tap
	case picking(String)

	/// A board this person can only view, with what can be opened
	case viewOnly(CanvasBarViewOnlySelection)
}

/// What's selected on a board this person can only view
enum CanvasBarViewOnlySelection: Equatable {
	case nothing
	case link
	case statement
	case source(isLink: Bool)
}

struct CanvasBarActions {
	var add: () -> Void
	var addText: () -> Void
	var addLink: () -> Void
	var edit: () -> Void
	var openSource: () -> Void
	var breakDown: () -> Void
	var delete: () -> Void
	var cancelPick: () -> Void

	/// Opens the analysis sheet for the selection
	var showAnnotations: () -> Void
}

/// The glass bar above the tab bar
struct CanvasBar: View {
	let mode: CanvasBarMode
	let actions: CanvasBarActions

	/// Whether the analysis has anything current on the selection
	var hasAnnotations = false

	@Environment(\.accessibilityReduceMotion)
	private var reduceMotion

	/// Gives each piece of glass an identity, so it joins with its neighbours as the bar changes
	@Namespace private var glass

	var body: some View {
		GlassEffectContainer(spacing: 12) {
			HStack(spacing: 12) {
				switch mode {
					case .idle:
						barButton("Add Statement", symbol: "plus", id: "add", action: actions.add)
						addSourceMenu

					case .statement:
						barButton("Edit", symbol: "square.and.pencil", id: "edit", action: actions.edit)
						annotationsButton
						barButton("Delete", symbol: "trash", id: "delete", role: .destructive, action: actions.delete)

					case let .source(isLink):
						if isLink {
							barButton("Open", symbol: "safari", id: "openSource", action: actions.openSource)
						} else {
							barButton("Edit", symbol: "square.and.pencil", id: "editSource", action: actions.openSource)
						}
						annotationsButton
						barButton("Break Down", symbol: "arrow.triangle.branch", id: "breakDownSource", action: actions.breakDown)
						barButton("Delete", symbol: "trash", id: "deleteSource", role: .destructive, action: actions.delete)

					case .link:
						annotationsButton
						barButton("Delete Arrow", symbol: "trash", id: "deleteLink", role: .destructive, action: actions.delete)

					case let .picking(prompt):
						Text(prompt)
							.font(.subheadline.weight(.medium))
							.padding(.horizontal, 14)
							.padding(.vertical, 10)
							.glassEffect(.regular, in: Capsule())
							.glassEffectID("prompt", in: glass)

						barButton("Cancel", symbol: "xmark", id: "cancelPick", action: actions.cancelPick)

					case let .viewOnly(selection):
						viewOnly(selection)
				}
			}
		}
		.animation(reduceMotion ? nil : .smooth, value: mode)
		.animation(reduceMotion ? nil : .smooth, value: hasAnnotations)
	}

	@ViewBuilder
	private var annotationsButton: some View {
		if hasAnnotations {
			barButton("Annotations", symbol: "text.magnifyingglass", id: "annotations", action: actions.showAnnotations)
		}
	}

	@ViewBuilder
	private func viewOnly(_ selection: CanvasBarViewOnlySelection) -> some View {
		Label("View only", systemImage: "eye")
			.font(.subheadline.weight(.medium))
			.padding(.horizontal, 14)
			.padding(.vertical, 10)
			.glassEffect(.regular, in: Capsule())
			.glassEffectID("viewOnly", in: glass)
			.accessibilityIdentifier("board.bar.viewOnly")

		switch selection {
			case .nothing, .link:
				EmptyView()
			case .statement:
				barButton("Open", symbol: "doc.text", id: "open", action: actions.edit)
			case let .source(isLink):
				barButton("Open", symbol: isLink ? "safari" : "doc.text", id: "openSource", action: actions.openSource)
		}
		annotationsButton
	}

	/// The glass goes around the menu rather than coming from `.buttonStyle(.glass)`. A menu with that style only gets its
	/// glass a few frames after it appears, so the container has nothing to join to and the whole bar cuts.
	private var addSourceMenu: some View {
		Menu {
			Button("Text", systemImage: "doc.text", action: actions.addText)
				.accessibilityIdentifier("board.bar.addText")
			Button("Web Link", systemImage: "safari", action: actions.addLink)
				.accessibilityIdentifier("board.bar.addLink")
		} label: {
			Label("Add Source", systemImage: "doc.badge.plus")
				.font(.subheadline.weight(.medium))
				.foregroundStyle(.primary)
				.padding(.horizontal, 18)
				.padding(.vertical, 10)
				.contentShape(Capsule())
		}
		.buttonStyle(.plain)
		.glassEffect(.regular.interactive(), in: Capsule())
		.glassEffectID("addSource", in: glass)
		.accessibilityIdentifier("board.bar.addSource")
	}

	private func barButton(
		_ title: String,
		symbol: String,
		id: String,
		role: ButtonRole? = nil,
		action: @escaping () -> Void
	) -> some View {
		Button(role: role, action: action) {
			Label(title, systemImage: symbol)
				.font(.subheadline.weight(.medium))
				.padding(.horizontal, 5)
				.padding(.vertical, 4)
		}
		.buttonStyle(.glass)
		.glassEffectID(id, in: glass)
		.tint(role == .destructive ? .red : nil)
		.accessibilityIdentifier("board.bar.\(id)")
	}
}

// MARK: - Notice

/// Why something was refused, until it's dismissed or a few seconds pass
struct CanvasNoticeView: View {
	let message: String
	let dismiss: () -> Void

	var body: some View {
		HStack(alignment: .firstTextBaseline, spacing: 10) {
			Image(systemName: "exclamationmark.triangle.fill")
				.foregroundStyle(.orange)

			Text(message)
				.font(.subheadline)
				.frame(maxWidth: .infinity, alignment: .leading)

			Button("Dismiss", systemImage: "xmark", action: dismiss)
				.labelStyle(.iconOnly)
				.buttonStyle(.plain)
				.foregroundStyle(.secondary)
				.accessibilityIdentifier("board.notice.dismiss")
		}
		.padding(14)
		.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
		.accessibilityElement(children: .combine)
		.accessibilityIdentifier("board.notice")
	}
}
