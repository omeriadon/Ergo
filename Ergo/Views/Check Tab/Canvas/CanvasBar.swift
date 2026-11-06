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

	/// Drawing an arrow from the statement with this title
	case connecting(String)
}

struct CanvasBarActions {
	var add: () -> Void
	var edit: () -> Void
	var connect: () -> Void
	var delete: () -> Void
	var cancel: () -> Void
}

/// The glass bar above the tab bar
struct CanvasBar: View {
	let mode: CanvasBarMode
	let actions: CanvasBarActions

	@Environment(\.accessibilityReduceMotion)
	private var reduceMotion

	var body: some View {
		GlassEffectContainer(spacing: 12) {
			HStack(spacing: 12) {
				switch mode {
					case .idle:
						barButton("Add Statement", symbol: "plus", id: "add", action: actions.add)

					case .statement:
						barButton("Edit", symbol: "square.and.pencil", id: "edit", action: actions.edit)
						barButton("Connect", symbol: "arrow.turn.down.right", id: "connect", action: actions.connect)
						barButton("Delete", symbol: "trash", id: "delete", role: .destructive, action: actions.delete)

					case .link:
						barButton("Delete Arrow", symbol: "trash", id: "deleteLink", role: .destructive, action: actions.delete)

					case let .connecting(title):
						connectingHint(title)
				}
			}
		}
		.animation(reduceMotion ? nil : .smooth, value: mode)
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
				.padding(.horizontal, 6)
				.padding(.vertical, 4)
		}
		.buttonStyle(.glass)
		.tint(role == .destructive ? .red : nil)
		.accessibilityIdentifier("check.bar.\(id)")
	}

	private func connectingHint(_ title: String) -> some View {
		HStack(spacing: 12) {
			VStack(alignment: .leading, spacing: 2) {
				Text("Tap the conclusion")
					.font(.subheadline.weight(.semibold))
				Text("“\(title)” will be its premise")
					.font(.caption)
					.foregroundStyle(.secondary)
					.lineLimit(1)
			}

			Button("Cancel", action: actions.cancel)
				.buttonStyle(.glass)
				.accessibilityIdentifier("check.bar.cancelConnect")
		}
		.padding(.leading, 16)
		.padding(.trailing, 6)
		.padding(.vertical, 6)
		.glassEffect(.regular, in: Capsule())
		.accessibilityElement(children: .contain)
	}
}

// MARK: - Notice

/// Why something was refused, in the validator's own words, until it's dismissed or a few seconds pass
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
				.accessibilityIdentifier("check.notice.dismiss")
		}
		.padding(14)
		.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
		.accessibilityElement(children: .combine)
		.accessibilityIdentifier("check.notice")
	}
}

// MARK: - Type to add

/// Type English and press return to add a statement beside the selected one
struct AddStatementField: View {
	@Binding var text: String
	var isFocused: FocusState<Bool>.Binding

	/// Says what return will do, for the placeholder
	let prompt: String

	let submit: () -> Void

	@Environment(\.accessibilityReduceMotion)
	private var reduceMotion

	private var canSubmit: Bool {
		!text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
	}

	var body: some View {
		HStack(spacing: 10) {
			Image(systemName: "text.cursor")
				.foregroundStyle(.secondary)

			TextField(prompt, text: $text)
				.focused(isFocused)
				.submitLabel(.send)
				.onSubmit(submit)
				.accessibilityLabel("Add a statement")
				.accessibilityIdentifier("check.addField")

			if canSubmit {
				Button("Add", systemImage: "arrow.up.circle.fill", action: submit)
					.labelStyle(.iconOnly)
					.font(.title2)
					.buttonStyle(.plain)
					.foregroundStyle(.tint)
					.transition(.opacity)
					.accessibilityIdentifier("check.addField.submit")
			}
		}
		.padding(.horizontal, 16)
		.padding(.vertical, 10)
		.glassEffect(.regular.interactive(), in: Capsule())
		.animation(reduceMotion ? nil : .smooth, value: canSubmit)
	}
}
