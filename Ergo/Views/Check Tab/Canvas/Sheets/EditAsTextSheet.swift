//
//  EditAsTextSheet.swift
//  Ergo
//
//  Created by Adon Omeri on 6/11/2026.
//

import Defaults
import ErgoLogic
import SwiftUI

/// Edits the whole board as one block of text, one statement a line, in English or in logic. The statements stay the
/// source of truth: Done matches the lines to them (`BoardStore.applyText`), so lines that didn't change keep their box and links.
struct EditAsTextSheet: View {
	enum Kind: Hashable {
		case english, logic

		var textKind: ArgumentTextKind {
			switch self {
				case .english: .english
				case .logic: .logic
			}
		}
	}

	@Environment(\.dismiss)
	private var dismiss

	@Environment(BoardStore.self)
	private var boardStore

	@Default(.logicLetters) private var logicLetters

	@State private var kind = Kind.english
	@State private var englishText = ""
	@State private var logicEntries: [LogicKeyboardEntry] = []

	/// What the board said when the sheet opened, to tell whether anything was edited
	@State private var original: (english: String, logic: [LogicKeyboardEntry])?

	/// What Done would do to the board, for the line under the editor
	@State private var preview = TextPreview.unchanged

	@State private var logicFocused = false
	@FocusState private var englishFocused: Bool

	@State private var confirmingRemoval: TextPreview.Summary?
	@State private var confirmingDiscard = false
	@State private var editingLetters = false

	init() {}

	private var letters: [String] {
		LogicLetters.resolved(logicLetters)
	}

	private var text: String {
		switch kind {
			case .english: englishText
			case .logic: LogicInputVocabulary(letters: letters).text(for: logicEntries)
		}
	}

	/// The editor on screen differs from what the board said. Only one is edited at a time, so the other never needs converting.
	private var isEdited: Bool {
		guard let original else { return false }
		return switch kind {
			case .english: englishText != original.english
			case .logic: logicEntries != original.logic
		}
	}

	var body: some View {
		NavigationStack {
			VStack(alignment: .leading, spacing: 14) {
				kindPicker

				TextBox(kind: kind, english: $englishText, logic: $logicEntries, logicFocused: $logicFocused, englishFocused: $englishFocused, descriptors: boardStore.current.descriptors) {
					editingLetters = true
				}

				TextStatusView(preview: preview)

				Text(footer)
					.font(.footnote)
					.foregroundStyle(.secondary)
					.accessibilityIdentifier("check.editAsText.footer")
			}
			.padding(15)
			.animation(.smooth, value: preview)
			.toolbarTitleDisplayMode(.inline)
			.navigationTitle("Edit as Text")
			.toolbar { toolbar }
		}
		.presentationDetents([.large])
		.presentationDragIndicator(.visible)
		// Swiping the sheet away would throw the edits out, Cancel asks first
		.interactiveDismissDisabled(isEdited)
		.onAppear(perform: load)
		.onChange(of: kind) {
			preview = .unchanged
		}
		.task(id: Draft(kind: kind, text: text)) {
			await refreshPreview()
		}
		.confirmationDialog(
			removalTitle,
			isPresented: Binding(get: { confirmingRemoval != nil }, set: {
				if !$0 {
					confirmingRemoval = nil
				}
			}),
			titleVisibility: .visible
		) {
			Button("Remove and Apply", role: .destructive) {
				confirmingRemoval = nil
				apply()
			}
		} message: {
			Text("Statements missing from the text are deleted, with every arrow to or from them.")
		}
		.confirmationDialog("Discard your edits?", isPresented: $confirmingDiscard, titleVisibility: .visible) {
			Button("Discard Edits", role: .destructive) {
				dismiss()
			}
		}
		.sheet(isPresented: $editingLetters) {
			LettersSheet(isPresented: $editingLetters)
		}
	}

	// MARK: - Parts

	private var kindPicker: some View {
		Picker("Format", selection: $kind) {
			Text("English").tag(Kind.english)
			Text("Logic").tag(Kind.logic)
		}
		.pickerStyle(.segmented)
		// Switching would drop the edits, or need a translation to carry them across
		.disabled(isEdited)
		.accessibilityHint(isEdited ? "Apply or cancel your edits to switch" : "")
		.accessibilityIdentifier("check.editAsText.kind")
	}

	private var footer: String {
		switch kind {
			case .english: "One statement per line. Finish with a line starting Therefore to name the conclusion."
			case .logic: "Separate statements with commas or new lines. Finish with ∴ and the conclusion."
		}
	}

	@ToolbarContentBuilder
	private var toolbar: some ToolbarContent {
		ToolbarItem(placement: .topBarLeading) {
			Button(role: .cancel) {
				if isEdited {
					confirmingDiscard = true
				} else {
					dismiss()
				}
			}
			.accessibilityIdentifier("check.editAsText.cancel")
		}

		ToolbarItem(placement: .topBarTrailing) {
			Button(role: .confirm, action: done) {
				Label("Done", systemImage: "checkmark")
			}
			.buttonStyle(.glassProminent)
			.accessibilityLabel("Done")
			.accessibilityIdentifier("check.editAsText.done")
		}

		ToolbarItem(placement: .keyboard) {
			// Logic has its own keyboard, with its own button for this
			if kind == .english {
				Button("Hide Keyboard", systemImage: "keyboard.chevron.compact.down") {
					englishFocused = false
				}
			}
		}
	}

	private var removalTitle: String {
		guard let summary = confirmingRemoval else { return "Remove statements?" }
		return "Remove \(TextPreview.count(summary.removed, "box", plural: "boxes"))\(summary.removedLinks == 0 ? "" : " and \(TextPreview.count(summary.removedLinks, "link"))")?"
	}

	// MARK: - Loading

	private func load() {
		guard original == nil else { return }
		let map = boardStore.current.map
		englishText = ArgumentText.text(of: map, kind: .english)
		logicEntries = ArgumentText.entries(for: map)
		original = (englishText, logicEntries)
	}

	// MARK: - Previewing

	/// Waits for a pause in typing, then says what Done would do. The same call Done makes, so they never disagree.
	private func refreshPreview() async {
		guard isEdited else {
			preview = .unchanged
			return
		}

		try? await Task.sleep(for: .milliseconds(400))
		guard !Task.isCancelled else { return }

		preview = TextPreview(of: evaluate(), in: boardStore.current.map)
	}

	private func evaluate() -> Result<ArgumentTextChange<Statement, Link>, ArgumentTextProblem> {
		let map = boardStore.current.map
		let text = text
		return Result { () throws(ArgumentTextProblem) in
			try ArgumentText.apply(text: text, kind: kind.textKind, letters: letters, to: map)
		}
	}

	// MARK: - Applying

	private func done() {
		guard isEdited else {
			dismiss()
			return
		}

		switch evaluate() {
			case let .failure(problem):
				preview = .problem(problem.message)
			case let .success(change):
				if change.removed.isEmpty {
					apply()
				} else {
					confirmingRemoval = TextPreview.Summary(change, in: boardStore.current.map)
				}
		}
	}

	private func apply() {
		let wasBlank = boardStore.current.isEmpty

		let change: ArgumentTextChange<Statement, Link>
		do {
			change = try boardStore.applyText(text, kind: kind.textKind)
		} catch {
			preview = .problem(error.message)
			return
		}

		// Nothing was there to keep, so it's laid out fresh instead of squeezed beside the empty box a new board starts with
		if wasBlank, !change.added.isEmpty {
			for statement in boardStore.current.statements where statement.isEmpty && !change.added.contains(statement.id) {
				boardStore.deleteStatement(id: statement.id)
			}
			boardStore.arrange()
		}

		dismiss()
	}
}

// MARK: - Draft

/// What the editor holds, so the preview restarts when either changes
private struct Draft: Hashable {
	let kind: EditAsTextSheet.Kind
	let text: String
}

// MARK: - Text box

private struct TextBox: View {
	let kind: EditAsTextSheet.Kind
	@Binding var english: String
	@Binding var logic: [LogicKeyboardEntry]
	@Binding var logicFocused: Bool
	var englishFocused: FocusState<Bool>.Binding
	let descriptors: [String]
	let editLetters: () -> Void

	var body: some View {
		ZStack {
			switch kind {
				case .english:
					TextEditor(text: $english)
						.textEditorStyle(.plain)
						.focused(englishFocused)
						.scrollDismissesKeyboard(.interactively)
						.accessibilityLabel("English text")
						.accessibilityIdentifier("check.editAsText.englishEditor")

				case .logic:
					LogicTextEditor(
						entries: $logic,
						isFocused: $logicFocused,
						descriptors: descriptors,
						onEditLetters: editLetters
					)
					.accessibilityLabel("Logic text")
					.accessibilityIdentifier("check.editAsText.logicEditor")
			}
		}
		.padding(15)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 20))
	}
}

// MARK: - Preview

/// What applying the text would do, or why it can't
private enum TextPreview: Equatable {
	case unchanged
	case change(Summary)
	case problem(String)

	struct Summary: Equatable {
		var edited: Int
		var added: Int
		var removed: Int

		/// Arrows that go with the removed statements
		var removedLinks: Int

		init(_ change: ArgumentTextChange<Statement, Link>, in map: ArgumentMap<Statement, Link>) {
			edited = change.edited.count
			added = change.added.count
			removed = change.removed.count
			removedLinks = map.links.count(where: { change.removed.contains($0.premise) || change.removed.contains($0.conclusion) })
		}

		/// "2 edited, 1 added, 1 removed", nothing for what didn't happen
		var text: String {
			let parts = [
				edited == 0 ? nil : "\(edited) edited",
				added == 0 ? nil : "\(added) added",
				removed == 0 ? nil : "\(removed) removed",
			].compactMap(\.self)
			return parts.isEmpty ? "No changes" : parts.joined(separator: ", ")
		}
	}

	init(of result: Result<ArgumentTextChange<Statement, Link>, ArgumentTextProblem>, in map: ArgumentMap<Statement, Link>) {
		switch result {
			case let .failure(problem):
				self = .problem(problem.message)
			case let .success(change):
				self = .change(Summary(change, in: map))
		}
	}

	static func count(_ count: Int, _ noun: String, plural: String? = nil) -> String {
		"\(count) \(count == 1 ? noun : plural ?? noun + "s")"
	}
}

private struct TextStatusView: View {
	let preview: TextPreview

	var body: some View {
		ZStack(alignment: .leading) {
			switch preview {
				case .unchanged:
					EmptyView()

				case let .change(summary):
					Label(summary.text, systemImage: "arrow.triangle.2.circlepath")
						.font(.subheadline)
						.foregroundStyle(.secondary)
						.accessibilityIdentifier("check.editAsText.summary")

				case let .problem(message):
					MessageRow(symbol: "xmark.circle.fill", color: .red, title: message)
						.accessibilityIdentifier("check.editAsText.problem")
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.accessibilityElement(children: .contain)
	}
}

// MARK: - Letters

/// The letters editor over this sheet, so the text isn't lost to the one the router shows
private struct LettersSheet: View {
	@Binding var isPresented: Bool

	@Environment(BoardStore.self)
	private var boardStore

	var body: some View {
		@Bindable var boardStore = boardStore

		NavigationStack {
			LogicLettersView(descriptors: $boardStore.current.descriptors)
				.toolbar {
					ToolbarItem(placement: .topBarTrailing) {
						Button(role: .close) {
							isPresented = false
						}
					}
				}
		}
	}
}
