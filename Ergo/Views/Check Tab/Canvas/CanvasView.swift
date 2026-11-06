//
//  CanvasView.swift
//  Ergo
//
//  Created by Adon Omeri on 6/11/2026.
//

import Defaults
import ErgoLogic
import SwiftUI

/// What is selected: a box or an arrow, never both
enum CanvasSelection: Hashable {
	case statement(Statement.ID)
	case link(Link.ID)
}

/// What the checker's answers depend on, so they're only worked out again when one of these changes
private struct CanvasCheckKey: Equatable {
	struct Item: Equatable {
		let id: Statement.ID
		let position: CanvasPoint
		let logic: [LogicKeyboardEntry]
	}

	let statements: [Item]
	let links: [Link]
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
	private struct ZoomSource {
		let id: Statement.ID
		let frame: CGRect
	}

	private enum Sheet: Identifiable {
		case editAsText
		case breakDown
		case check(Statement.ID)

		var id: String {
			switch self {
				case .editAsText: "editAsText"
				case .breakDown: "breakDown"
				case let .check(id): "check.\(id.uuidString)"
			}
		}
	}

	let zoomNamespace: Namespace.ID
	let history: CanvasHistory

	/// The editor is open on top, so the bars hide instead of showing around the edge of the zoom
	var isCovered = false

	let openEditor: (Statement.ID) -> Void

	@Environment(BoardStore.self)
	private var boardStore

	@Environment(NavigationManager.self)
	private var navigation

	@Environment(\.accessibilityReduceMotion)
	private var reduceMotion

	@Environment(\.accessibilityVoiceOverEnabled)
	private var voiceOverEnabled

	@Environment(\.undoManager)
	private var undoManager

	@Environment(CatalogStore.self)
	private var catalog

	@Default(.logicLetters) private var logicLetters

	// What's on screen
	@State private var board = CanvasBoardController()
	@State private var room = CanvasRoom()

	/// Where the editor zooms out of. The box itself is hosted separately, out of reach of the zoom transition, so this
	/// is an invisible stand-in over it.
	@State private var zoomSource: ZoomSource?

	/// The board as it was when a drag began, for its undo step
	@State private var dragBefore: CanvasHistory.Snapshot?

	@State private var selection: CanvasSelection?

	/// An arrow being dragged out of this box, and the box it's over
	@State private var connecting: Statement.ID?
	@State private var connectTarget: Statement.ID?

	/// Whether the arrow being drawn makes the selected box a conclusion rather than a premise
	@State private var connectsAsConclusion = false

	/// Whether the canvas still fits itself to the board as the room changes. Adding a box ends it, so the bar changing
	/// for the new selection can't move the canvas again afterwards.
	@State private var keepsFitting = true

	// Messages, checks and sheets
	@State private var notice: String?
	@State private var verdicts: [Statement.ID: BoxVerdict] = [:]
	@State private var sheet: Sheet?
	@State private var sheetStart: CanvasHistory.Snapshot?
	@State private var sheetName = ""
	@State private var outlineOverride: Bool?

	// Undo
	@State private var canUndo = false
	@State private var canRedo = false

	private var board: LogicBoard {
		boardStore.current
	}

	private var letters: [String] {
		LogicLetters.resolved(logicLetters)
	}

	/// Animations are skipped entirely under Reduce Motion
	private var motion: Animation? {
		reduceMotion ? nil : .smooth
	}

	/// VoiceOver gets the outline unless it's switched off, everyone else gets the canvas unless it's switched on
	private var showsOutline: Bool {
		outlineOverride ?? voiceOverEnabled
	}

	var body: some View {
		ZStack {
			if showsOutline {
				outline
			} else {
				canvas
			}
		}
		// Inside the inset, so the room it reads already has the bars taken off
		.onGeometryChange(for: CanvasRoom.self, of: { CanvasRoom($0) }) { new in
			room = new
			fitUntilMoved()
		}
		.safeAreaInset(edge: .bottom, spacing: 0) { bottomStack }
		.toolbar { toolbar }
		.sheet(item: $sheet, onDismiss: sheetClosed) { sheet in
			sheetContent(sheet)
		}
		.modifier(lifecycle)
	}

	// MARK: - Canvas

	private var canvas: some View {
		let relations = boxRelations
		let connectable = connectableStatements
		let boxes = board.statements.map { statement in
			CanvasBoxModel(
				statement: statement,
				letters: letters,
				descriptors: board.descriptors,
				relations: relations[statement.id] ?? BoxRelations(),
				verdict: verdicts[statement.id],
				appearance: appearance(of: statement.id, connectable: connectable)
			)
		}

		return CanvasBoard(
			boxes: boxes,
			links: board.links,
			selectedStatement: selectedStatement,
			selectedLink: selectedLink,
			controller: board,
			catalog: catalog,
			actions: actions(for:),
			dragStarted: dragStarted,
			moved: boxMoved,
			tapBackground: backgroundTapped,
			connectStarted: connectStarted,
			connectTargetChanged: { connectTarget = $0 },
			connectEnded: connectEnded
		)
		.overlay(alignment: .topLeading) { zoomSourceAnchor }
		.ignoresSafeArea()
	}

	@ViewBuilder
	private var zoomSourceAnchor: some View {
		if let zoomSource {
			Color.clear
				.frame(width: zoomSource.frame.width, height: zoomSource.frame.height)
				.matchedTransitionSource(id: zoomSource.id, in: zoomNamespace)
				.offset(x: zoomSource.frame.minX, y: zoomSource.frame.minY)
				.allowsHitTesting(false)
				.accessibilityHidden(true)
		}
	}

	private var outline: some View {
		CanvasOutlineView(
			board: board,
			verdicts: verdicts,
			edit: edit,
			delete: delete,
			showCheck: { sheet = .check($0) },
			link: { link(premise: $0, conclusion: $1) },
			unlink: deleteLink
		)
		.ignoresSafeArea(.keyboard)
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

			// The outline has its own edit and delete on each row, so it only needs Add
			CanvasBar(mode: showsOutline ? .idle : barMode, actions: barActions)
		}
		.padding(.horizontal, 16)
		.padding(.bottom, 8)
		.background(alignment: .bottom) {
			BackdropBlur(radius: 1, fade: .top)
				.frame(maxWidth: .infinity)
				.ignoresSafeArea(edges: .bottom)
				.allowsHitTesting(false)
		}
		.opacity(isCovered ? 0 : 1)
		.allowsHitTesting(!isCovered)
		.animation(motion, value: notice)
		.animation(.easeOut(duration: 0.15), value: isCovered)
	}

	private var barMode: CanvasBarMode {
		switch activeSelection {
			case .statement: .statement
			case .link: .link
			case nil: .idle
		}
	}

	private var barActions: CanvasBarActions {
		CanvasBarActions(
			add: addStatement,
			edit: {
				if case let .statement(id)? = activeSelection {
					edit(id)
				}
			},
			delete: {
				switch activeSelection {
					case let .statement(id)?: delete(id)
					case let .link(id)?: deleteLink(id)
					case nil: break
				}
			}
		)
	}

	// MARK: - Toolbar

	@ToolbarContentBuilder
	private var toolbar: some ToolbarContent {
		ToolbarItemGroup(placement: .topBarTrailing) {
			if !showsOutline {
				Button("Fit", systemImage: "arrow.up.left.and.down.right.magnifyingglass") {
					fit(animated: true)
				}
				.accessibilityIdentifier("check.fitButton")
			}

			Button("Boards", systemImage: "text.page.and.line.vertical.and.text.page") {
				navigation.presentSheet(.boards)
			}
			.accessibilityIdentifier("check.boardsButton")
		}

		ToolbarOverflowMenu {
			menuContent
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
			Button("Edit as Text", systemImage: "text.alignleft") { present(.editAsText, named: "Edit as Text") }
			Button("Break Down", systemImage: "list.bullet.indent") { present(.breakDown, named: "Break Down") }
		}

		Section {
			Button(showsOutline ? "Show Canvas" : "Show Outline", systemImage: showsOutline ? "square.grid.3x3" : "list.bullet") {
				outlineOverride = !showsOutline
			}
		}
	}

	// MARK: - Sheets

	@ViewBuilder
	private func sheetContent(_ sheet: Sheet) -> some View {
		switch sheet {
			case .editAsText:
				EditAsTextSheet()
			case .breakDown:
				BreakDownSheet()
			case let .check(id):
				ArgumentCheckSheet(statementID: id)
		}
	}

	/// The text and breakdown sheets edit the board themselves, so what they did becomes one undo step on the way out
	private func present(_ sheet: Sheet, named name: String) {
		sheetStart = history.snapshot()
		sheetName = name
		self.sheet = sheet
	}

	private func sheetClosed() {
		defer { sheetStart = nil }
		guard let before = sheetStart else { return }

		let grew = (history.snapshot()?.statements.count ?? 0) != before.statements.count
		history.register(before, name: sheetName)
		if grew {
			fit(animated: true)
		}
	}

	// MARK: - Appearance

	private func appearance(of id: Statement.ID, connectable: Set<Statement.ID>?) -> BoxAppearance {
		if let connectable {
			if id == connecting {
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
		let titles = Dictionary(board.statements.map { ($0.id, StatementBoxView.title(of: $0, letters: letters)) }, uniquingKeysWith: { first, _ in first })

		var relations: [Statement.ID: BoxRelations] = [:]
		for link in board.links where link.premise != link.conclusion {
			guard let premise = titles[link.premise], let conclusion = titles[link.conclusion] else { continue }
			relations[link.conclusion, default: BoxRelations()].premises.append(premise)
			relations[link.premise, default: BoxRelations()].conclusions.append(conclusion)
		}
		return relations
	}

	/// While drawing an arrow, the boxes it could end at. Nil when not drawing one.
	private var connectableStatements: Set<Statement.ID>? {
		guard let connecting else { return nil }
		let map = board.map
		return Set(board.statements.map(\.id).filter { target in
			ArgumentMapValidator.problem(adding: newLink(from: connecting, to: target), to: map) == nil
		})
	}

	/// A selection that's gone (deleted here, or on another device) is no selection
	private var activeSelection: CanvasSelection? {
		switch selection {
			case let .statement(id)?:
				board.statement(id) == nil ? nil : selection
			case let .link(id)?:
				board.links.contains { $0.id == id } ? selection : nil
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
			showCheck: verdicts[id] == nil ? nil : { sheet = .check(id) },
			nudge: { nudge(id, columns: $0, rows: $1) }
		)
	}

	private func select(_ id: Statement.ID) {
		selection = .statement(id)
	}

	private func edit(_ id: Statement.ID) {
		selection = .statement(id)

		if let statement = board.statement(id) {
			let box = CanvasRect.box(at: statement.position)
			let transform = board.transform
			let origin = transform.screen(CanvasPoint(x: box.minX, y: box.minY))
			zoomSource = ZoomSource(
				id: id,
				frame: CGRect(x: origin.x, y: origin.y, width: box.size.width * transform.scale, height: box.size.height * transform.scale)
			)
		}

		// A turn isn't enough: the stand-in has to be laid out in the window, which takes a frame or two,
		// or the transition finds no source view and falls back to a plain push
		Task {
			try? await Task.sleep(for: .milliseconds(50))
			openEditor(id)
		}
	}

	private func dragStarted(_ id: Statement.ID) {
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

	// MARK: - Connecting

	private func connectStarted(_ id: Statement.ID, asConclusion: Bool) {
		selection = .statement(id)
		connectsAsConclusion = asConclusion
		connecting = id
	}

	/// Let go over a box, the arrow is drawn or the notice says why not. Let go anywhere else, nothing happens.
	private func connectEnded(_ source: Statement.ID, target: Statement.ID?) {
		connecting = nil
		connectTarget = nil
		if let target {
			let new = newLink(from: source, to: target)
			link(premise: new.premise, conclusion: new.conclusion)
		}
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
			show(problem.message)
		}
		return problem == nil
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

		if keepsFitting, !board.hasBeenMoved {
			fit(animated: true)
		}
		keepsFitting = false
	}

	private var statementLimitMessage: String {
		ArgumentMapProblem.tooManyStatements(
			limit: ArgumentMapValidator.defaultMaximumStatements,
			found: board.statements.count + 1
		).message
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
			board.move(to: fitted, animation: motion)
		}
	}

	// MARK: - Placing

	/// The middle of the part of the canvas the bars leave free
	private var viewCentre: CanvasPoint {
		board.transform.canvas(CGPoint(x: room.free.midX, y: room.free.midY))
	}

	/// The grid point nearest `point` where a box fits, else the nearest gap
	private func freeSpot(near point: CanvasPoint) -> CanvasPoint {
		let target = CanvasGrid.snapped(point)
		let occupied = board.statements.map(\.position)
		let box = CanvasRect.box(at: target)
		if !occupied.contains(where: { box.intersects(.box(at: $0), margin: CanvasLayout.minimumGap) }) {
			return target
		}
		return CanvasLayout.place(near: target, side: .below, occupied: occupied)
	}

	private var fitted: CanvasTransform {
		CanvasTransform.fitting(board.statements.map { .box(at: $0.position) }, in: room.viewport, insets: room.insets)
	}

	private func fit(animated: Bool) {
		board.move(to: fitted, animation: animated ? motion : nil)
	}

	// MARK: - Background

	private func backgroundTapped(at point: CanvasPoint) {
		let link = LinkHitTest.link(
			near: point,
			tolerance: 24 / board.transform.scale,
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
			checkKey: CanvasCheckKey(
				statements: board.statements.map { .init(id: $0.id, position: $0.position, logic: $0.logic) },
				links: board.links
			),
			notice: notice,
			undoManager: undoManager,
			computeVerdicts: computeVerdicts,
			clearNotice: { notice = nil },
			wireHistory: wireHistory,
			refreshUndo: refreshUndo,
			tabLeft: { sheet = nil }
		)
	}

	/// Keeps the whole board in view until the person moves the canvas or adds a box. The first measurements come in before
	/// the screen has finished laying out, so fitting only once would fit to the wrong room. Not while the editor is what
	/// changed the room.
	private func fitUntilMoved() {
		guard keepsFitting, !board.hasBeenMoved, !isCovered, room.viewport.width > 0, room.viewport.height > 0 else { return }
		fit(animated: false)
	}

	/// Off the main actor, after a pause, so typing in a box or dragging it never waits on a truth table
	private func computeVerdicts() async {
		try? await Task.sleep(for: .milliseconds(400))
		guard !Task.isCancelled else { return }

		let result = await BoxVerdict.all(in: boardStore.current.map)
		guard !Task.isCancelled else { return }
		verdicts = result
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
	let checkKey: CanvasCheckKey
	let notice: String?
	let undoManager: UndoManager?
	let computeVerdicts: () async -> Void
	let clearNotice: () -> Void
	let wireHistory: () -> Void
	let refreshUndo: () -> Void
	let tabLeft: () -> Void

	@Environment(NavigationManager.self)
	private var navigation

	func body(content: Content) -> some View {
		content
			.task(id: checkKey) {
				await computeVerdicts()
			}
			.task(id: notice) {
				guard notice != nil else { return }
				try? await Task.sleep(for: .seconds(7))
				guard !Task.isCancelled else { return }
				clearNotice()
			}
			.task(id: undoManager.map(ObjectIdentifier.init)) {
				wireHistory()
			}
			.onChange(of: navigation.selectedTab) {
				tabLeft()
			}
			.onReceive(NotificationCenter.default.publisher(for: .NSUndoManagerDidCloseUndoGroup)) { _ in refreshUndo() }
			.onReceive(NotificationCenter.default.publisher(for: .NSUndoManagerDidUndoChange)) { _ in refreshUndo() }
			.onReceive(NotificationCenter.default.publisher(for: .NSUndoManagerDidRedoChange)) { _ in refreshUndo() }
	}
}
