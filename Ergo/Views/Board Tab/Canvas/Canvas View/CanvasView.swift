//
//  CanvasView.swift
//  Ergo
//
//  Created by Adon Omeri on 8/11/2026.
//

import ErgoLogic
import ErgoProtocol
import ErgoShare
import ErgoSync
import SwiftUI

/// The current board as an argument map: boxes you can drag, arrows between them, and a bar for what you can do
/// with the selection. Everything is edited through `BoardStore`; this view only holds what's on screen
/// (pan, zoom, selection).
struct CanvasView: View {
	let history: CanvasHistory

	@Environment(BoardStore.self)
	var boardStore

	@Environment(NavigationManager.self)
	var navigation

	@Environment(BoardAnalysisStore.self)
	var analysis

	@Environment(SyncController.self)
	var sync

	@Environment(\.accessibilityReduceMotion)
	var reduceMotion

	@Environment(\.undoManager)
	var undoManager

	// What's on screen
	@State var canvasBoard = CanvasBoardController()
	@State var room = CanvasRoom()

	/// The statement whose editor is open
	@State var editing: Statement.ID?

	/// The editor is on top, or still on its way there or back, so the bars hide instead of showing around the edge of
	/// the zoom. It outlasts `editing`, because the keyboard going away changes the room while the editor is closing.
	@State var isCovered = false

	/// The board as it was when a drag began, for its undo step
	@State var dragBefore: CanvasHistory.Snapshot?

	@State var selection: CanvasSelection?

	/// An arrow being dragged out of this box, and the box it's over
	@State var connecting: Statement.ID?
	@State var connectTarget: Statement.ID?

	/// Whether the arrow being drawn makes the selected box a conclusion rather than a premise
	@State var connectsAsConclusion = false

	@State var pick: BoxPick?
	@State var sourceSheet: SourceSheet?

	/// Whether the canvas still fits itself to the board as the room changes. Adding a box ends it, so the bar changing
	/// for the new selection can't move the canvas again afterwards.
	@State var keepsFitting = true

	/// Messages
	@State var notice: String?

	@State var canUndo = false
	@State var canRedo = false

	/// Set while the search bar is open
	@State var find: FindState?

	var board: Board {
		boardStore.current
	}

	/// Read every time, so a role changed by the owner applies straight away
	var isReadOnly: Bool {
		!boardStore.canEdit(board.id)
	}

	/// Animations are skipped entirely under Reduce Motion
	var motion: Animation? {
		reduceMotion ? nil : .smooth
	}

	var body: some View {
		ZStack {
			canvas
		}
		// Inside the inset, so the room it reads already has the bars taken off
		.onGeometryChange(for: CanvasRoom.self, of: { CanvasRoom($0) }) { new in
			room = new
			fitUntilMoved()
		}
		.safeAreaInset(edge: .bottom, spacing: 0) { bottomStack }
		.safeAreaBar(edge: .top, spacing: 0) { findBar }
		.onChange(of: currentFindMatch?.selection) { reveal(currentFindMatch) }
		.toolbar { toolbar }
		// The search bar takes the navigation bar's place
		.toolbarVisibility(find == nil ? .automatic : .hidden, for: .navigationBar)
		.background { editorPresenter }
		.sheet(item: $sourceSheet, content: sourceSheet(for:))
		.modifier(lifecycle)
	}

	var editorPresenter: some View {
		StatementEditorPresenter(
			statementID: editing,
			canvasBoard: canvasBoard,
			editor: { [boardStore] id in
				AnyView(
					StatementEditorScreen(statementID: id, close: { editing = nil })
						.environment(boardStore)
						.fontDesign(.rounded)
				)
			},
			closed: { isCovered = false }
		)
	}

	private var bottomStack: some View {
		CanvasBottomStack(
			notice: notice,
			mode: barMode,
			actions: barActions,
			hasAnnotations: selectionHasAnnotations,
			isCovered: isCovered,
			motion: motion,
			clearNotice: { notice = nil }
		)
	}

	private var toolbar: some ToolbarContent {
		CanvasToolbar(
			board: board,
			isReadOnly: isReadOnly,
			isAnalysing: isAnalysing,
			hasAnalysis: hasAnalysis,
			canUndo: canUndo,
			canRedo: canRedo,
			fit: { fit(animated: true) },
			showBoards: { navigation.presentSheet(.boards) },
			search: startFind,
			quickAI: { navigation.presentSheet(.quickAI(board.id)) },
			showAnalysis: { navigation.presentSheet(.boardAnalysis(board.id, focus: nil)) },
			deepResearch: deepResearch,
			sendToChat: { navigation.presentSheet(.addToChat(.text(board.chatText))) },
			undo: { undoManager?.undo() },
			redo: { undoManager?.redo() },
			arrange: arrange
		)
	}

	// MARK: - Canvas

	var canvas: some View {
		let relations = boxRelations
		let connectable = connectableStatements
		let isReadOnly = isReadOnly
		let shown = shownAnalysis
		let counts = shown.counts
		let supports = shown.supports
		let comments = shown.comments
		let boxes = board.statements.map { statement in
			CanvasBoxModel(
				statement: statement,
				relations: relations[statement.id] ?? BoxRelations(),
				appearance: appearance(of: statement.id, connectable: connectable),
				isReadOnly: isReadOnly,
				annotationCount: counts[statement.id] ?? 0,
				support: supports[statement.id],
				comment: comments[statement.id],
				findHighlight: find?.query
			)
		}

		return CanvasBoard(
			boxes: boxes,
			links: board.links,
			strengths: shown.strengths,
			notedLinks: Set(board.links.map(\.id).filter { comments[$0] != nil }),
			sources: sources(counts: counts, comments: comments),
			regions: regions,
			// While picking, a box is tapped rather than dragged from, so its handles stay away
			selectedStatement: activePick == nil ? selectedStatement : nil,
			selectedLink: selectedLink,
			selectedSource: selectedSource,
			controller: canvasBoard,
			isReadOnly: isReadOnly,
			actions: actions(for:),
			sourceActions: sourceActions(for:),
			dragStarted: dragStarted,
			moved: boxMoved,
			tapBackground: backgroundTapped,
			connectStarted: connectStarted,
			connectTargetChanged: { connectTarget = $0 },
			connectEnded: connectEnded,
			deleteLink: deleteLink,
			sourceDragStarted: sourceDragStarted,
			sourceMoved: sourceMoved,
			showAnalysis: showAnalysis(of:)
		)
		.ignoresSafeArea()
	}

	/// Dimmed while drawing an arrow, since one can't end on a source
	func sources(counts: [UUID: Int], comments: [UUID: BoardAnalysisComment]) -> [CanvasSourceModel] {
		let isReadOnly = isReadOnly
		return board.sources.map { source in
			let appearance: BoxAppearance = if linkSource != nil {
				.unavailable
			} else {
				activeSelection == .source(source.id) ? .selected : .normal
			}
			return CanvasSourceModel(source: source, appearance: appearance, isReadOnly: isReadOnly, annotationCount: counts[source.id] ?? 0, comment: comments[source.id], findHighlight: find?.query)
		}
	}

	/// Only sources with cards have a region
	var regions: [CanvasRegionModel] {
		board.sources.compactMap { source in
			let members = board.members(of: source.id).map(\.id)
			return members.isEmpty ? nil : CanvasRegionModel(source: source.id, members: members)
		}
	}
}
