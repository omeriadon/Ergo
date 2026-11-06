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

/// The current page as an argument map: boxes you can drag, arrows between them, and a bar for what you can do
/// with the selection. Everything is edited through `PageStore`; this view only holds what's on screen
/// (pan, zoom, selection).
struct CanvasView: View {
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

	@Environment(PageStore.self)
	private var pageStore

	@Environment(NavigationManager.self)
	private var navigation

	@Environment(\.accessibilityReduceMotion)
	private var reduceMotion

	@Environment(\.accessibilityVoiceOverEnabled)
	private var voiceOverEnabled

	@Environment(\.undoManager)
	private var undoManager

	@Default(.logicLetters) private var logicLetters

	// What's on screen
	@State private var transform = CanvasTransform()
	@State private var room = CanvasRoom()
	@State private var needsFit = true
	@State private var selection: CanvasSelection?
	@State private var connecting: Statement.ID?

	// Messages, checks and sheets
	@State private var notice: String?
	@State private var verdicts: [Statement.ID: BoxVerdict] = [:]
	@State private var sheet: Sheet?
	@State private var sheetStart: CanvasHistory.Snapshot?
	@State private var sheetName = ""
	@State private var outlineOverride: Bool?

	// Type to add
	@State private var newText = ""
	@FocusState private var addFocused: Bool

	// Undo
	@State private var canUndo = false
	@State private var canRedo = false

	private var page: LogicPage {
		pageStore.current
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
			fitFirstTime()
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
		CanvasSurface(
			transform: $transform,
			tapBackground: backgroundTapped,
			pinchedPastLimit: pinchedPastLimit
		) {
			canvasContent
		}
		.ignoresSafeArea()
	}

	/// In canvas units, inside the surface's one transform
	private var canvasContent: some View {
		let connectable = connectableStatements

		return CanvasBoard(
			page: page,
			letters: letters,
			relations: boxRelations,
			verdicts: verdicts,
			selectedStatement: selectedStatement,
			selectedLink: selectedLink,
			scale: transform.scale,
			history: history,
			zoomNamespace: zoomNamespace,
			appearance: { appearance(of: $0, connectable: connectable) },
			actions: actions(for:),
			dragStarted: dragStarted,
			moved: boxMoved
		)
	}

	private var outline: some View {
		CanvasOutlineView(
			page: page,
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

			if !showsOutline {
				CanvasBar(mode: barMode, actions: barActions)
			}

			AddStatementField(text: $newText, isFocused: $addFocused, prompt: addPrompt, submit: submitNewStatement)
		}
		.padding(.horizontal, 16)
		.padding(.bottom, 8)
		.opacity(isCovered ? 0 : 1)
		.allowsHitTesting(!isCovered)
		.animation(motion, value: notice)
		.animation(.easeOut(duration: 0.15), value: isCovered)
	}

	private var barMode: CanvasBarMode {
		if let connecting, let statement = page.statement(connecting) {
			return .connecting(StatementBoxView.title(of: statement, letters: letters))
		}
		switch activeSelection {
			case .statement: return .statement
			case .link: return .link
			case nil: return .idle
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
			connect: {
				if case let .statement(id)? = activeSelection {
					startConnecting(from: id)
				}
			},
			delete: {
				switch activeSelection {
					case let .statement(id)?: delete(id)
					case let .link(id)?: deleteLink(id)
					case nil: break
				}
			},
			cancel: { connecting = nil }
		)
	}

	private var addPrompt: String {
		if case .statement? = activeSelection {
			"Add a premise of this statement"
		} else {
			"Add a statement"
		}
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

			Button("Pages", systemImage: "text.page.and.line.vertical.and.text.page") {
				navigation.presentSheet(.pages)
			}
			.accessibilityIdentifier("check.pagesButton")
		}

		ToolbarItem(placement: .topBarTrailing) {
			Menu("More", systemImage: "ellipsis") {
				menuContent
			}
			.accessibilityIdentifier("check.moreMenu")
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
			Button("Fit", systemImage: "arrow.up.left.and.down.right.magnifyingglass") { fit(animated: true) }
				.disabled(showsOutline)
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

	/// The text and breakdown sheets edit the page themselves, so what they did becomes one undo step on the way out
	private func present(_ sheet: Sheet, named name: String) {
		addFocused = false
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
			return connectable.contains(id) ? .normal : .unavailable
		}
		return activeSelection == .statement(id) ? .selected : .normal
	}

	/// Titles of what each box is joined to, for its ∴ mark and for VoiceOver
	private var boxRelations: [Statement.ID: BoxRelations] {
		let page = page
		let titles = Dictionary(page.statements.map { ($0.id, StatementBoxView.title(of: $0, letters: letters)) }, uniquingKeysWith: { first, _ in first })

		var relations: [Statement.ID: BoxRelations] = [:]
		for link in page.links where link.premise != link.conclusion {
			guard let premise = titles[link.premise], let conclusion = titles[link.conclusion] else { continue }
			relations[link.conclusion, default: BoxRelations()].premises.append(premise)
			relations[link.premise, default: BoxRelations()].conclusions.append(conclusion)
		}
		return relations
	}

	/// While drawing an arrow, the boxes it could end at. Nil when not drawing one.
	private var connectableStatements: Set<Statement.ID>? {
		guard let connecting else { return nil }
		let map = page.map
		return Set(page.statements.map(\.id).filter { target in
			ArgumentMapValidator.problem(adding: Link(premise: connecting, conclusion: target), to: map) == nil
		})
	}

	/// A selection that's gone (deleted here, or on another device) is no selection
	private var activeSelection: CanvasSelection? {
		switch selection {
			case let .statement(id)?:
				page.statement(id) == nil ? nil : selection
			case let .link(id)?:
				page.links.contains { $0.id == id } ? selection : nil
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
			connect: { startConnecting(from: id) },
			delete: { delete(id) },
			showCheck: verdicts[id] == nil ? nil : { sheet = .check(id) },
			nudge: { nudge(id, columns: $0, rows: $1) }
		)
	}

	private func select(_ id: Statement.ID) {
		addFocused = false
		if connecting != nil {
			connect(to: id)
		} else {
			selection = .statement(id)
		}
	}

	private func edit(_ id: Statement.ID) {
		addFocused = false
		connecting = nil
		selection = .statement(id)
		openEditor(id)
	}

	private func dragStarted(_ id: Statement.ID) {
		addFocused = false
		selection = .statement(id)
	}

	private func boxMoved(_ id: Statement.ID, to position: CanvasPoint, before: CanvasHistory.Snapshot?) {
		pageStore.moveStatement(id: id, to: position)
		history.register(before, name: "Move Statement")
	}

	/// For VoiceOver, which can't drag: a step of the grid at a time
	private func nudge(_ id: Statement.ID, columns: Int, rows: Int) {
		guard let statement = page.statement(id) else { return }
		let target = CanvasGrid.snapped(CanvasPoint(
			x: statement.position.x + Double(columns) * CanvasGrid.step,
			y: statement.position.y + Double(rows) * CanvasGrid.step
		))
		history.perform("Move Statement") {
			pageStore.moveStatement(id: id, to: target)
		}
	}

	// MARK: - Connecting

	private func startConnecting(from id: Statement.ID) {
		addFocused = false
		selection = .statement(id)
		connecting = id
		if let statement = page.statement(id) {
			AccessibilityNotification.Announcement("Connecting from \(StatementBoxView.title(of: statement, letters: letters)). Choose the conclusion.").post()
		}
	}

	/// Draws the arrow from the box being connected. A refused arrow leaves connecting on, so another box can be tried.
	private func connect(to target: Statement.ID) {
		guard let source = connecting else { return }
		if link(premise: source, conclusion: target) {
			connecting = nil
			selection = .statement(target)
		}
	}

	/// True when the arrow was drawn, otherwise says why not
	@discardableResult
	private func link(premise: Statement.ID, conclusion: Statement.ID) -> Bool {
		var problem: ArgumentMapProblem?
		history.perform("Add Link") {
			withAnimation(motion) {
				problem = pageStore.link(premise: premise, conclusion: conclusion)
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
		addFocused = false
		guard page.statements.count < ArgumentMapValidator.defaultMaximumStatements else {
			show(statementLimitMessage)
			return
		}

		history.perform("Add Statement") {
			withAnimation(motion) {
				selection = pageStore.addStatement(at: freeSpot(near: viewCentre)).map { .statement($0) }
			}
		}
	}

	/// Return in the field: a statement beside the selected one and, if one is selected, a premise of it
	private func submitNewStatement() {
		let text = newText.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !text.isEmpty else { return }
		guard page.statements.count < ArgumentMapValidator.defaultMaximumStatements else {
			show(statementLimitMessage)
			return
		}

		var anchor: Statement.ID?
		if case let .statement(id)? = activeSelection {
			anchor = id
		}

		history.perform("Add Statement") {
			withAnimation(motion) {
				if let anchor {
					if let id = pageStore.addStatement(english: text, near: anchor, side: .left) {
						pageStore.link(premise: id, conclusion: anchor)
						selection = .statement(id)
					}
				} else if let id = pageStore.addStatement(english: text, at: freeSpot(near: viewCentre)) {
					selection = .statement(id)
				}
			}
		}

		newText = ""
		addFocused = true
		if case let .statement(id)? = activeSelection {
			reveal(id)
		}
	}

	private var statementLimitMessage: String {
		ArgumentMapProblem.tooManyStatements(
			limit: ArgumentMapValidator.defaultMaximumStatements,
			found: page.statements.count + 1
		).message
	}

	private func delete(_ id: Statement.ID) {
		history.perform("Delete Statement") {
			withAnimation(motion) {
				pageStore.deleteStatement(id: id)
			}
		}
		if connecting == id {
			connecting = nil
		}
	}

	private func deleteLink(_ id: Link.ID) {
		history.perform("Delete Link") {
			withAnimation(motion) {
				pageStore.unlink(id: id)
			}
		}
	}

	private func arrange() {
		history.perform("Arrange") {
			withAnimation(motion) {
				pageStore.arrange()
				transform = fitted
			}
		}
	}

	// MARK: - Placing

	/// The middle of the part of the canvas the bars leave free
	private var viewCentre: CanvasPoint {
		transform.canvas(CGPoint(x: room.free.midX, y: room.free.midY))
	}

	/// The grid point nearest `point` where a box fits, else the nearest gap
	private func freeSpot(near point: CanvasPoint) -> CanvasPoint {
		let target = CanvasGrid.snapped(point)
		let occupied = page.statements.map(\.position)
		let box = CanvasRect.box(at: target)
		if !occupied.contains(where: { box.intersects(.box(at: $0), margin: CanvasLayout.minimumGap) }) {
			return target
		}
		return CanvasLayout.place(near: target, side: .below, occupied: occupied)
	}

	private var fitted: CanvasTransform {
		CanvasTransform.fitting(page.statements.map { .box(at: $0.position) }, in: room.viewport, insets: room.insets)
	}

	private func fit(animated: Bool) {
		withAnimation(animated ? motion : nil) {
			transform = fitted
		}
	}

	/// Pans just enough to bring the box into view
	private func reveal(_ id: Statement.ID) {
		guard let statement = page.statement(id) else { return }
		let target = transform.revealing(.box(at: statement.position), in: room.viewport, insets: room.insets)
		if target != transform {
			withAnimation(motion) {
				transform = target
			}
		}
	}

	// MARK: - Background

	private func backgroundTapped(at point: CGPoint) {
		addFocused = false
		if connecting != nil {
			connecting = nil
			return
		}

		let link = LinkHitTest.link(
			near: transform.canvas(point),
			tolerance: 24 / transform.scale,
			in: page.links,
			positions: Dictionary(page.statements.map { ($0.id, $0.position) }, uniquingKeysWith: { first, _ in first })
		)
		selection = link.map { .link($0) }
	}

	/// Pinching in on a box after the zoom has run out opens it, the way tapping it would
	private func pinchedPastLimit(at point: CGPoint) {
		let canvasPoint = transform.canvas(point)
		let touched = page.statements.last { CanvasRect.box(at: $0.position).contains(canvasPoint) }?.id
		if let target = touched ?? selectedStatement {
			edit(target)
		}
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
				statements: page.statements.map { .init(id: $0.id, position: $0.position, logic: $0.logic) },
				links: page.links
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

	/// The first time there's room to lay out, show the whole page
	private func fitFirstTime() {
		guard needsFit, room.viewport.width > 0, room.viewport.height > 0 else { return }
		needsFit = false
		fit(animated: false)
	}

	/// Off the main actor, after a pause, so typing in a box or dragging it never waits on a truth table
	private func computeVerdicts() async {
		try? await Task.sleep(for: .milliseconds(400))
		guard !Task.isCancelled else { return }

		let result = await BoxVerdict.all(in: pageStore.current.map)
		guard !Task.isCancelled else { return }
		verdicts = result
	}

	private func wireHistory() {
		history.store = pageStore
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
