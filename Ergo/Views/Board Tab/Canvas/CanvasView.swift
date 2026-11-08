//
//  CanvasView.swift
//  Ergo
//
//  Created by Adon Omeri on 6/11/2026.
//

import ErgoLogic
import ErgoShare
import SwiftUI

/// What is selected: a box, a source or an arrow, only one at a time
enum CanvasSelection: Hashable {
	case statement(Statement.ID)
	case link(Link.ID)
	case source(BoardSource.ID)
}

/// Which source sheet is open
private enum SourceSheet: Identifiable {
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
}

/// A box's menu asked for another box, and the next one tapped is the answer
private enum BoxPick: Equatable {
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
private nonisolated struct CanvasRoom: Equatable {
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

/// The current board as an argument map: boxes you can drag, arrows between them, and a bar for what you can do
/// with the selection. Everything is edited through `BoardStore`; this view only holds what's on screen
/// (pan, zoom, selection).
struct CanvasView: View {
	let history: CanvasHistory

	@Environment(BoardStore.self)
	private var boardStore

	@Environment(NavigationManager.self)
	private var navigation

	@Environment(\.accessibilityReduceMotion)
	private var reduceMotion

	@Environment(\.undoManager)
	private var undoManager

	// What's on screen
	@State private var canvasBoard = CanvasBoardController()
	@State private var room = CanvasRoom()

	/// The statement whose editor is open
	@State private var editing: Statement.ID?

	/// The editor is on top, or still on its way there or back, so the bars hide instead of showing around the edge of
	/// the zoom. It outlasts `editing`, because the keyboard going away changes the room while the editor is closing.
	@State private var isCovered = false

	/// The board as it was when a drag began, for its undo step
	@State private var dragBefore: CanvasHistory.Snapshot?

	@State private var selection: CanvasSelection?

	/// An arrow being dragged out of this box, and the box it's over
	@State private var connecting: Statement.ID?
	@State private var connectTarget: Statement.ID?

	/// Whether the arrow being drawn makes the selected box a conclusion rather than a premise
	@State private var connectsAsConclusion = false

	@State private var pick: BoxPick?

	@State private var sourceSheet: SourceSheet?

	/// Whether the canvas still fits itself to the board as the room changes. Adding a box ends it, so the bar changing
	/// for the new selection can't move the canvas again afterwards.
	@State private var keepsFitting = true

	/// Messages
	@State private var notice: String?

	// Undo
	@State private var canUndo = false
	@State private var canRedo = false

	private var board: Board {
		boardStore.current
	}

	/// Read every time, so a role changed by the owner applies straight away
	private var isReadOnly: Bool {
		!boardStore.canEdit(board.id)
	}

	/// Animations are skipped entirely under Reduce Motion
	private var motion: Animation? {
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
		.toolbar { toolbar }
		.background { editorPresenter }
		.sheet(item: $sourceSheet, content: sourceEditor)
		.modifier(lifecycle)
	}

	private var editorPresenter: some View {
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

	// MARK: - Canvas

	private var canvas: some View {
		let relations = boxRelations
		let connectable = connectableStatements
		let isReadOnly = isReadOnly
		let boxes = board.statements.map { statement in
			CanvasBoxModel(
				statement: statement,
				relations: relations[statement.id] ?? BoxRelations(),
				appearance: appearance(of: statement.id, connectable: connectable),
				isReadOnly: isReadOnly
			)
		}

		return CanvasBoard(
			boxes: boxes,
			links: board.links,
			sources: sources,
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
			sourceMoved: sourceMoved
		)
		.ignoresSafeArea()
	}

	/// Dimmed while drawing an arrow, since one can't end on a source
	private var sources: [CanvasSourceModel] {
		let isReadOnly = isReadOnly
		return board.sources.map { source in
			let appearance: BoxAppearance = if linkSource != nil {
				.unavailable
			} else {
				activeSelection == .source(source.id) ? .selected : .normal
			}
			return CanvasSourceModel(source: source, appearance: appearance, isReadOnly: isReadOnly)
		}
	}

	/// Only sources with cards have a region
	private var regions: [CanvasRegionModel] {
		board.sources.compactMap { source in
			let members = board.members(of: source.id).map(\.id)
			return members.isEmpty ? nil : CanvasRegionModel(source: source.id, members: members)
		}
	}

	// MARK: - Bottom

	private var bottomStack: some View {
		VStack(spacing: 10) {
			if let notice {
				CanvasNoticeView(message: notice) {
					self.notice = nil
				}
				.transition(.move(edge: .bottom).combined(with: .opacity))
			}

			CanvasBar(mode: barMode, actions: barActions)
		}
		.padding(.horizontal, 16)
		.padding(.bottom, 8)
		// The stack is only as wide as what's in it, and the blur goes all the way across
		.frame(maxWidth: .infinity)
		.background(alignment: .bottom) {
			BackdropBlur(radius: 1, fade: .top)
				.ignoresSafeArea(edges: [.horizontal, .bottom])
				.allowsHitTesting(false)
		}
		.opacity(isCovered ? 0 : 1)
		.allowsHitTesting(!isCovered)
		.animation(motion, value: notice)
		.animation(.easeOut(duration: 0.15), value: isCovered)
	}

	private var barMode: CanvasBarMode {
		if isReadOnly {
			return switch activeSelection {
				case .statement: .viewOnly(.statement)
				case let .source(id): .viewOnly(.source(isLink: board.source(id)?.link != nil))
				case .link, nil: .viewOnly(.nothing)
			}
		}
		if let activePick {
			return .picking(prompt(for: activePick))
		}
		return switch activeSelection {
			case .statement: .statement
			case .link: .link
			case let .source(id): .source(isLink: board.source(id)?.link != nil)
			case nil: .idle
		}
	}

	private var barActions: CanvasBarActions {
		CanvasBarActions(
			add: addStatement,
			addText: { sourceSheet = .newText },
			addLink: { sourceSheet = .newLink },
			edit: {
				if case let .statement(id)? = activeSelection {
					edit(id)
				}
			},
			openSource: {
				if case let .source(id)? = activeSelection {
					open(id)
				}
			},
			breakDown: {
				if case let .source(id)? = activeSelection {
					navigation.presentSheet(.breakDownSource(id))
				}
			},
			delete: {
				switch activeSelection {
					case let .statement(id)?: delete(id)
					case let .link(id)?: deleteLink(id)
					case let .source(id)?: deleteSource(id)
					case nil: break
				}
			},
			cancelPick: { pick = nil }
		)
	}

	// MARK: - Toolbar

	@ToolbarContentBuilder
	private var toolbar: some ToolbarContent {
		ToolbarItemGroup(placement: .topBarTrailing) {
			Button("Fit", systemImage: "arrow.up.left.and.down.right.magnifyingglass") {
				fit(animated: true)
			}
			.accessibilityIdentifier("board.fitButton")

			Button("Boards", systemImage: "text.page.and.line.vertical.and.text.page") {
				navigation.presentSheet(.boards)
			}
			.accessibilityIdentifier("board.boardsButton")
		}

		// Everything in it changes the board
		if !isReadOnly {
			ToolbarOverflowMenu {
				menuContent
			}
		}
	}

	@ViewBuilder
	private var menuContent: some View {
		Section {
			Button("Undo", systemImage: "arrow.uturn.backward") { undoManager?.undo() }
				.disabled(!canUndo)
			Button("Redo", systemImage: "arrow.uturn.forward") { undoManager?.redo() }
				.disabled(!canRedo)
		}

		Section {
			Button("Arrange", systemImage: "rectangle.3.group") { arrange() }
		}

		Section {
			BoardPeopleButton(board: board)
		}
	}

	// MARK: - Appearance

	private func appearance(of id: Statement.ID, connectable: Set<Statement.ID>?) -> BoxAppearance {
		if let connectable {
			if id == linkSource {
				return .connectSource
			}
			guard connectable.contains(id) else {
				return .unavailable
			}
			return id == connectTarget ? .selected : .normal
		}
		return activeSelection == .statement(id) ? .selected : .normal
	}

	/// Titles of what each box is joined to, for its ∴ mark and for VoiceOver
	private var boxRelations: [Statement.ID: BoxRelations] {
		let board = board
		let titles = Dictionary(board.statements.map { ($0.id, StatementBoxView.title(of: $0)) }, uniquingKeysWith: { first, _ in first })

		var relations: [Statement.ID: BoxRelations] = [:]
		for link in board.links where link.premise != link.conclusion {
			guard let premise = titles[link.premise], let conclusion = titles[link.conclusion] else { continue }
			relations[link.conclusion, default: BoxRelations()].premises.append(premise)
			relations[link.premise, default: BoxRelations()].conclusions.append(conclusion)
		}
		return relations
	}

	/// While drawing an arrow, the boxes it could end at, and while removing one, the boxes it could be going to.
	/// Nil when doing neither.
	private var connectableStatements: Set<Statement.ID>? {
		if case let .unlink(id) = activePick {
			return Set(board.links.filter { $0.premise == id }.map(\.conclusion) + board.links.filter { $0.conclusion == id }.map(\.premise))
		}
		guard let linkSource else { return nil }
		let map = board.map
		return Set(board.statements.map(\.id).filter { target in
			ArgumentMapValidator.problem(adding: newLink(from: linkSource, to: target), to: map) == nil
		})
	}

	/// The box an arrow is coming out of, by dragging or by picking
	private var linkSource: Statement.ID? {
		connecting ?? activePick?.source
	}

	/// A pick whose box is gone (deleted here, or on another device) is no pick
	private var activePick: BoxPick? {
		guard !isReadOnly else { return nil }
		return pick.flatMap { board.statement($0.source) == nil ? nil : $0 }
	}

	/// A selection that's gone (deleted here, or on another device) is no selection
	private var activeSelection: CanvasSelection? {
		switch selection {
			case let .statement(id)?:
				board.statement(id) == nil ? nil : selection
			case let .link(id)?:
				board.links.contains { $0.id == id } ? selection : nil
			case let .source(id)?:
				board.source(id) == nil ? nil : selection
			case nil:
				nil
		}
	}

	// MARK: - Box actions

	private func actions(for statement: Statement) -> BoxActions {
		let id = statement.id
		return BoxActions(
			select: { select(id) },
			edit: { edit(id) },
			delete: { delete(id) },
			connect: { pickToConnect(id, asConclusion: $0) },
			removeLink: { pickToUnlink(id) },
			nudge: { nudge(id, columns: $0, rows: $1) }
		)
	}

	private func sourceActions(for source: BoardSource) -> SourceActions {
		let id = source.id
		return SourceActions(
			select: { selectSource(id) },
			open: { open(id) },
			edit: { sourceSheet = .edit(id) },
			breakDown: { navigation.presentSheet(.breakDownSource(id)) },
			delete: { deleteSource(id) },
			nudge: { nudgeSource(id, columns: $0, rows: $1) }
		)
	}

	private func select(_ id: Statement.ID) {
		if let activePick {
			finish(activePick, with: id)
		} else {
			selection = .statement(id)
		}
	}

	private func edit(_ id: Statement.ID) {
		pick = nil
		selection = .statement(id)
		isCovered = true
		editing = id
	}

	private func dragStarted(_ id: Statement.ID) {
		pick = nil
		selection = .statement(id)
		dragBefore = history.snapshot()
	}

	private func boxMoved(_ id: Statement.ID, to position: CanvasPoint) {
		boardStore.moveStatement(id: id, to: position)
		history.register(dragBefore, name: "Move Statement")
		dragBefore = nil
	}

	/// For VoiceOver, which can't drag: a step of the grid at a time
	private func nudge(_ id: Statement.ID, columns: Int, rows: Int) {
		guard let statement = board.statement(id) else { return }
		let target = CanvasGrid.snapped(CanvasPoint(
			x: statement.position.x + Double(columns) * CanvasGrid.step,
			y: statement.position.y + Double(rows) * CanvasGrid.step
		))
		history.perform("Move Statement") {
			boardStore.moveStatement(id: id, to: target)
		}
	}

	// MARK: - Sources

	/// A source can't be the answer to a pick, so tapping one just ends it
	private func selectSource(_ id: BoardSource.ID) {
		pick = nil
		selection = .source(id)
	}

	/// Links always go to the browser, never a view in the app. Text opens its editor.
	private func open(_ id: BoardSource.ID) {
		pick = nil
		selection = .source(id)
		guard let source = board.source(id) else { return }

		if let link = source.link {
			if link.isWebLink {
				UIApplication.shared.open(link)
			}
		} else {
			sourceSheet = .edit(id)
		}
	}

	private func sourceDragStarted(_ id: BoardSource.ID) {
		pick = nil
		selection = .source(id)
		dragBefore = history.snapshot()
	}

	private func sourceMoved(_ id: BoardSource.ID, to position: CanvasPoint) {
		boardStore.moveSource(id: id, to: position)
		history.register(dragBefore, name: "Move Source")
		dragBefore = nil
	}

	private func nudgeSource(_ id: BoardSource.ID, columns: Int, rows: Int) {
		guard let source = board.source(id) else { return }
		let target = CanvasGrid.snapped(CanvasPoint(
			x: source.position.x + Double(columns) * CanvasGrid.step,
			y: source.position.y + Double(rows) * CanvasGrid.step
		))
		history.perform("Move Source") {
			boardStore.moveSource(id: id, to: target)
		}
	}

	private func deleteSource(_ id: BoardSource.ID) {
		history.perform("Delete Source") {
			withAnimation(motion) {
				boardStore.deleteSource(id: id)
			}
		}
	}

	@ViewBuilder
	private func sourceEditor(_ sheet: SourceSheet) -> some View {
		switch sheet {
			case .newText:
				SourceEditorSheet(kind: .text, save: addSource)
			case .newLink:
				SourceEditorSheet(kind: .link, save: addSource)
			case let .edit(id):
				if let source = board.source(id) {
					if isReadOnly {
						SourceReaderSheet(source: source)
					} else {
						SourceEditorSheet(kind: source.link == nil ? .text : .link, content: source.content) { content in
							boardStore.updateSource(id, content: content)
							findTitle(of: id)
						}
					}
				}
		}
	}

	/// A new source where the person is looking
	private func addSource(_ content: BoardSource.Content) {
		var added: BoardSource.ID?
		history.perform("Add Source") {
			withAnimation(motion) {
				let id = boardStore.addSource(content, at: freeSpot(near: viewCentre))
				selection = .source(id)
				added = id
			}
		}
		if keepsFitting, !canvasBoard.hasBeenMoved {
			fit(animated: true)
		}
		keepsFitting = false
		if let added {
			findTitle(of: added)
		}
	}

	/// A link typed in has no title, and the card says more with the page's. It's fine if the page won't load.
	private func findTitle(of id: BoardSource.ID) {
		guard case let .link(url, nil)? = board.source(id)?.content else { return }
		Task {
			guard let title = try? await PageReader.read(url).title else { return }
			boardStore.updateSource(id, content: .link(url, title: title))
		}
	}

	// MARK: - Connecting

	private func connectStarted(_ id: Statement.ID, asConclusion: Bool) {
		selection = .statement(id)
		connectsAsConclusion = asConclusion
		connecting = id
	}

	/// Let go over a box, the arrow is drawn or the notice says why not. Let go on empty canvas, a new box goes there.
	private func connectEnded(_ source: Statement.ID, drop: ConnectionDrop) {
		connecting = nil
		connectTarget = nil
		switch drop {
			case let .box(target):
				let new = newLink(from: source, to: target)
				link(premise: new.premise, conclusion: new.conclusion)
			case let .space(point):
				addLinked(to: source, near: point)
			case .nowhere:
				break
		}
	}

	/// A new empty box where the arrow was let go, which is a premise of `source` when the arrow came out of the top of
	/// it, and a conclusion when it came out of the bottom
	private func addLinked(to source: Statement.ID, near point: CanvasPoint) {
		guard board.statements.count < ArgumentMapValidator.defaultMaximumStatements else {
			show(statementLimitMessage)
			return
		}

		let side: CanvasLayout.Side = connectsAsConclusion ? .above : .below
		history.perform(connectsAsConclusion ? "Add Premise" : "Add Conclusion") {
			withAnimation(motion) {
				guard let new = boardStore.addStatement(at: freeSpot(near: point, side: side)) else { return }
				let arrow = newLink(from: source, to: new)
				boardStore.link(premise: arrow.premise, conclusion: arrow.conclusion)
				selection = .statement(new)
			}
		}
		keepsFitting = false
	}

	/// The arrow for dragging from `source` to `target`, which way round depending on the handle it came from
	private func newLink(from source: Statement.ID, to target: Statement.ID) -> Link {
		connectsAsConclusion
			? Link(premise: target, conclusion: source)
			: Link(premise: source, conclusion: target)
	}

	/// True when the arrow was drawn, otherwise says why not
	@discardableResult
	private func link(premise: Statement.ID, conclusion: Statement.ID) -> Bool {
		var problem: ArgumentMapProblem?
		history.perform("Add Link") {
			withAnimation(motion) {
				problem = boardStore.link(premise: premise, conclusion: conclusion)
			}
		}
		if let problem {
			show(linkMessage(for: problem, premise: premise, conclusion: conclusion))
		}
		return problem == nil
	}

	/// Why an arrow wasn't drawn, the way a person would say it rather than in the validator's words. An arrow back
	/// along an existing one counts as a loop to the validator, but all anyone sees is two cards already connected.
	private func linkMessage(for problem: ArgumentMapProblem, premise: Statement.ID, conclusion: Statement.ID) -> String {
		let isReversed = board.links.contains { $0.premise == conclusion && $0.conclusion == premise }
		return switch problem {
			case .duplicateLink:
				"These cards are already connected"
			case .cycle where isReversed:
				"These cards are already connected"
			case .cycle:
				"That would make a loop, so these cards can't be connected"
			case .selfLink:
				"A card can't connect to itself"
			case .danglingLink:
				"That card isn't on this board anymore"
			default:
				problem.message
		}
	}

	// MARK: - Picking

	private func pickToConnect(_ id: Statement.ID, asConclusion: Bool) {
		connectsAsConclusion = asConclusion
		start(.connect(id))
	}

	private func pickToUnlink(_ id: Statement.ID) {
		start(.unlink(id))
	}

	private func start(_ new: BoxPick) {
		selection = .statement(new.source)
		pick = new
		AccessibilityNotification.Announcement(prompt(for: new)).post()
	}

	private func prompt(for pick: BoxPick) -> String {
		switch pick {
			case .connect: connectsAsConclusion ? "Tap its premise" : "Tap its conclusion"
			case .unlink: "Tap the linked statement"
		}
	}

	/// The box itself cancels. A box that can't be the answer leaves the pick open, so another can be tapped.
	private func finish(_ pick: BoxPick, with id: Statement.ID) {
		guard id != pick.source else {
			self.pick = nil
			return
		}

		switch pick {
			case let .connect(source):
				let new = newLink(from: source, to: id)
				if link(premise: new.premise, conclusion: new.conclusion) {
					self.pick = nil
				}
			case let .unlink(source):
				let arrow = board.links.first { ($0.premise == source && $0.conclusion == id) || ($0.premise == id && $0.conclusion == source) }
				if let arrow {
					deleteLink(arrow.id)
					self.pick = nil
				}
		}
	}

	// MARK: - Adding and deleting

	/// A new empty box where the person is looking
	private func addStatement() {
		guard board.statements.count < ArgumentMapValidator.defaultMaximumStatements else {
			show(statementLimitMessage)
			return
		}

		history.perform("Add Statement") {
			withAnimation(motion) {
				selection = boardStore.addStatement(at: freeSpot(near: viewCentre)).map { .statement($0) }
			}
		}

		if keepsFitting, !canvasBoard.hasBeenMoved {
			fit(animated: true)
		}
		keepsFitting = false
	}

	private var statementLimitMessage: String {
		"This board is full, it can only hold \(ArgumentMapValidator.defaultMaximumStatements) cards"
	}

	private func delete(_ id: Statement.ID) {
		history.perform("Delete Statement") {
			withAnimation(motion) {
				boardStore.deleteStatement(id: id)
			}
		}
	}

	private func deleteLink(_ id: Link.ID) {
		history.perform("Delete Link") {
			withAnimation(motion) {
				boardStore.unlink(id: id)
			}
		}
	}

	private func arrange() {
		history.perform("Arrange") {
			withAnimation(motion) {
				boardStore.arrange()
			}
			canvasBoard.move(to: fitted, animation: motion)
		}
	}

	// MARK: - Placing

	/// The middle of the part of the canvas the bars leave free
	private var viewCentre: CanvasPoint {
		canvasBoard.transform.canvas(CGPoint(x: room.free.midX, y: room.free.midY))
	}

	/// The grid point nearest `point` where a box fits, else the nearest gap on that `side` of it
	private func freeSpot(near point: CanvasPoint, side: CanvasLayout.Side = .below) -> CanvasPoint {
		let target = CanvasGrid.snapped(point)
		let occupied = board.statements.map(\.position) + board.sources.map(\.position)
		let box = CanvasRect.box(at: target)
		if !occupied.contains(where: { box.intersects(.box(at: $0), margin: CanvasLayout.minimumGap) }) {
			return target
		}
		return CanvasLayout.place(near: target, side: side, occupied: occupied)
	}

	private var fitted: CanvasTransform {
		CanvasTransform.fitting(board.occupiedRects, in: room.viewport, insets: room.insets)
	}

	private func fit(animated: Bool) {
		canvasBoard.move(to: fitted, animation: animated ? motion : nil)
	}

	// MARK: - Background

	private func backgroundTapped(at point: CanvasPoint) {
		guard activePick == nil else {
			pick = nil
			return
		}

		let link = LinkHitTest.link(
			near: point,
			tolerance: 24 / canvasBoard.transform.scale,
			in: board.links,
			positions: Dictionary(board.statements.map { ($0.id, $0.position) }, uniquingKeysWith: { first, _ in first })
		)
		selection = link.map { .link($0) }
	}

	private var selectedStatement: Statement.ID? {
		if case let .statement(id)? = activeSelection {
			id
		} else {
			nil
		}
	}

	private var selectedSource: BoardSource.ID? {
		if case let .source(id)? = activeSelection {
			id
		} else {
			nil
		}
	}

	private var selectedLink: Link.ID? {
		if case let .link(id)? = activeSelection {
			id
		} else {
			nil
		}
	}

	// MARK: - Notice

	private func show(_ message: String) {
		notice = message
		AccessibilityNotification.Announcement(message).post()
	}

	// MARK: - Lifecycle

	private var lifecycle: CanvasLifecycle {
		CanvasLifecycle(
			notice: notice,
			undoManager: undoManager,
			clearNotice: { notice = nil },
			wireHistory: wireHistory,
			refreshUndo: refreshUndo
		)
	}

	/// Keeps the whole board in view until the person moves the canvas or adds a box. The first measurements come in before
	/// the screen has finished laying out, so fitting only once would fit to the wrong room. Not while the editor is what
	/// changed the room.
	private func fitUntilMoved() {
		guard keepsFitting, !canvasBoard.hasBeenMoved, !isCovered, room.viewport.width > 0, room.viewport.height > 0 else { return }
		fit(animated: false)
	}

	private func wireHistory() {
		history.store = boardStore
		history.undoManager = undoManager
		history.didChange = refreshUndo
		refreshUndo()
	}

	private func refreshUndo() {
		canUndo = undoManager?.canUndo ?? false
		canRedo = undoManager?.canRedo ?? false
	}
}

// MARK: - Lifecycle modifier

/// The `onChange`s, tasks and observers of the canvas, kept out of `body` so it type-checks quickly
private struct CanvasLifecycle: ViewModifier {
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
