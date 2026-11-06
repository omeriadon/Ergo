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
}

struct CanvasBarActions {
	var add: () -> Void
	var edit: () -> Void
	var delete: () -> Void
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
						barButton("Delete", symbol: "trash", id: "delete", role: .destructive, action: actions.delete)

					case .link:
						barButton("Delete Arrow", symbol: "trash", id: "deleteLink", role: .destructive, action: actions.delete)
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
