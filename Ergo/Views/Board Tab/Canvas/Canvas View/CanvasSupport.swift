//
//  CanvasSupport.swift
//  Ergo
//
//  Created by Adon Omeri on 8/11/2026.
//

import ErgoLogic
import ErgoProtocol
import ErgoShare
import ErgoSync
import SwiftUI

/// What is selected: a box, a source or an arrow, only one at a time
enum CanvasSelection: Hashable {
	case statement(Statement.ID)
	case link(Link.ID)
	case source(BoardSource.ID)
}

/// Which source sheet is open
enum SourceSheet: Identifiable {
	case newText
	case newLink
	case edit(BoardSource.ID)

	var id: String {
		switch self {
			case .newText: "newText"
			case .newLink: "newLink"
			case let .edit(id): id.uuidString
		}
	}

	/// The source being edited, if one is
	var sourceID: BoardSource.ID? {
		if case let .edit(id) = self {
			id
		} else {
			nil
		}
	}
}

/// A box's menu asked for another box, and the next one tapped is the answer
enum BoxPick: Equatable {
	/// A new arrow, which way round depending on `connectsAsConclusion`
	case connect(Statement.ID)

	/// Removing the arrow between this box and the one tapped
	case unlink(Statement.ID)

	var source: Statement.ID {
		switch self {
			case let .connect(id), let .unlink(id): id
		}
	}
}

/// The room the canvas has, read in one go from the view that sits between the bars: all of the screen the canvas
/// covers, and what the navigation bar, tab bar, floating bar and keyboard take from it. Only Fit and placing boxes
/// use it. Nothing is laid out from it, so measuring it can't change what's measured.
nonisolated struct CanvasRoom: Equatable {
	var viewport = CGSize.zero
	var insets = EdgeInsets()

	init() {}

	init(_ proxy: GeometryProxy) {
		insets = proxy.safeAreaInsets
		viewport = CGSize(
			width: proxy.size.width + insets.leading + insets.trailing,
			height: proxy.size.height + insets.top + insets.bottom
		)
	}

	/// The part of the canvas nothing covers
	var free: CGRect {
		CGRect(
			x: insets.leading,
			y: insets.top,
			width: max(viewport.width - insets.leading - insets.trailing, 1),
			height: max(viewport.height - insets.top - insets.bottom, 1)
		)
	}
}

// MARK: - Lifecycle modifier

/// The `onChange`s, tasks and observers of the canvas, kept out of `body` so it type-checks quickly
struct CanvasLifecycle: ViewModifier {
	let notice: String?
	let undoManager: UndoManager?
	let clearNotice: () -> Void
	let wireHistory: () -> Void
	let refreshUndo: () -> Void

	func body(content: Content) -> some View {
		content
			.task(id: notice) {
				guard notice != nil else { return }
				try? await Task.sleep(for: .seconds(7))
				guard !Task.isCancelled else { return }
				clearNotice()
			}
			.task(id: undoManager.map(ObjectIdentifier.init)) {
				wireHistory()
			}
			.onReceive(NotificationCenter.default.publisher(for: .NSUndoManagerDidCloseUndoGroup)) { _ in refreshUndo() }
			.onReceive(NotificationCenter.default.publisher(for: .NSUndoManagerDidUndoChange)) { _ in refreshUndo() }
			.onReceive(NotificationCenter.default.publisher(for: .NSUndoManagerDidRedoChange)) { _ in refreshUndo() }
	}
}
