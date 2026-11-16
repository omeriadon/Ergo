//
//  BeliefDetailView.swift
//  Ergo
//
//  Created by Adon Omeri on 16/11/2026.
//

import Charts
import Defaults
import ErgoCatalog
import SwiftUI

/// One belief: its claim, how sure, a line of every rating, and the history with notes. Pushed as
/// `LibraryRoute.belief`.
struct BeliefDetailView: View {
	let id: Belief.ID

	@Default(.beliefs) private var ledger

	var body: some View {
		if let belief = ledger.belief(id) {
			BeliefDetailContent(belief: belief)
		} else {
			ContentUnavailableView("Belief Not Found", systemImage: "questionmark.circle", description: Text("error: it was deleted"))
		}
	}
}

private struct BeliefDetailContent: View {
	let belief: Belief

	@Default(.beliefs) private var ledger

	@Environment(\.dismiss)
	private var dismiss

	@State private var isRewording = false
	@State private var rewording = ""
	@State private var isConfirmingDelete = false

	private var set: BeliefQuestionSet? {
		belief.question.flatMap(BeliefQuestionBank.set(containing:))
	}

	private var color: Color {
		set.map { HexColor.color($0.color) } ?? .accentColor
	}

	var body: some View {
		List {
			Section {
				BeliefDetailHeader(belief: belief, set: set, color: color)
			}

			Section("How Sure") {
				BeliefRating(belief: belief, color: color)
			}

			if belief.changes.count(where: { $0.to != nil }) > 1 {
				Section("Over Time") {
					BeliefChart(changes: belief.changes, color: color)
				}
			}

			Section("History") {
				ForEach(belief.changes.reversed()) { change in
					BeliefChangeRow(change: change, beliefID: belief.id, isFirst: change.id == belief.changes.first?.id)
				}
			}

			if let entries = belief.question.flatMap(BeliefQuestionBank.question)?.entries, !entries.isEmpty {
				Section("In the Library") {
					BeliefEntryLinks(entries: entries)
				}
			}
		}
		.navigationTitle("Belief")
		.navigationBarTitleDisplayMode(.inline)
		.toolbar {
			ToolbarItem(placement: .primaryAction) {
				menu
			}
		}
		.alert("Reword", isPresented: $isRewording) {
			TextField("Belief", text: $rewording, axis: .vertical)
			Button("Cancel", role: .cancel) {}
			Button("Save") {
				ledger.reword(belief.id, to: rewording)
			}
		} message: {
			Text("Rewording keeps its history.")
		}
		.confirmationDialog("Delete this belief and its history?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
			Button("Delete", role: .destructive) {
				dismiss()
				ledger.delete(belief.id)
			}
		}
	}

	private var menu: some View {
		Menu("More", systemImage: "ellipsis") {
			if belief.question == nil {
				Button("Reword", systemImage: "pencil") {
					rewording = belief.statement
					isRewording = true
				}
			}

			Button(belief.isArchived ? "Unarchive" : "Archive", systemImage: belief.isArchived ? "tray.and.arrow.up" : "archivebox") {
				ledger.setArchived(!belief.isArchived, belief.id)
			}

			Button("Delete", systemImage: "trash", role: .destructive) {
				isConfirmingDelete = true
			}
		}
		.accessibilityIdentifier("belief.menu")
	}
}

private struct BeliefDetailHeader: View {
	let belief: Belief
	let set: BeliefQuestionSet?
	let color: Color

	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			if let set {
				Text(set.title)
					.font(.subheadline.weight(.semibold))
					.foregroundStyle(color)
			}

			Text(belief.displayStatement)
				.font(.title3.bold())
				.fontDesign(.rounded)
				.textSelection(.enabled)

			Text("Since \(belief.created.formatted(date: .abbreviated, time: .omitted))")
				.font(.caption)
				.foregroundStyle(.secondary)
		}
		.padding(.vertical, 4)
	}
}

/// The slider, saved a moment after it stops so dragging through values doesn't log each one, and "No view"
private struct BeliefRating: View {
	let belief: Belief
	let color: Color

	@Default(.beliefs) private var ledger

	@State private var value: Double
	@State private var hasMoved = false

	init(belief: Belief, color: Color) {
		self.belief = belief
		self.color = color
		_value = State(initialValue: Double(belief.confidence ?? BeliefScale.middle))
	}

	private var confidence: Int {
		BeliefScale.snapped(value)
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			if belief.confidence == nil, !hasMoved {
				Text("No view. Move the slider to rate it.")
					.font(.subheadline)
					.foregroundStyle(.secondary)
			}

			BeliefSlider(value: $value, color: color)

			if belief.confidence != nil {
				Button("No View") {
					hasMoved = false
					ledger.rate(belief.id, confidence: nil)
				}
				.buttonStyle(.glass)
			}
		}
		.padding(.vertical, 4)
		.onChange(of: confidence) {
			hasMoved = true
		}
		.task(id: confidence) {
			try? await Task.sleep(for: .seconds(1))
			// Checked after waiting, since No View can be tapped in that second
			guard hasMoved, !Task.isCancelled else { return }
			ledger.rate(belief.id, confidence: confidence)
		}
		.onDisappear {
			// Leaving within the second still keeps the rating
			if hasMoved {
				ledger.rate(belief.id, confidence: confidence)
			}
		}
	}
}

/// Every rating as a point on a line, "No view" left out
private struct BeliefChart: View {
	let changes: [Belief.Change]
	let color: Color

	var body: some View {
		Chart(changes.filter { $0.to != nil }) { change in
			LineMark(x: .value("Date", change.date), y: .value("Confidence", change.to ?? 0))
				.interpolationMethod(.monotone)
			PointMark(x: .value("Date", change.date), y: .value("Confidence", change.to ?? 0))
		}
		.foregroundStyle(color)
		.chartYScale(domain: 0 ... 100)
		.chartYAxis {
			AxisMarks(values: [0, 50, 100]) { value in
				AxisGridLine()
				AxisValueLabel {
					if let number = value.as(Int.self) {
						Text("\(number)%")
					}
				}
			}
		}
		.frame(height: 180)
		.padding(.vertical, 6)
	}
}

private struct BeliefChangeRow: View {
	let change: Belief.Change
	let beliefID: Belief.ID
	let isFirst: Bool

	@Default(.beliefs) private var ledger

	@State private var isEditingNote = false
	@State private var note = ""

	private var summary: String {
		let to = change.to.map(BeliefScale.words) ?? "No view"
		if isFirst {
			return to
		}
		guard change.hasMoved else {
			return "\(to), again"
		}
		return "\(change.from.map(BeliefScale.words) ?? "No view") → \(to)"
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 4) {
			HStack {
				Text(summary)
				Spacer(minLength: 0)
				Text(change.date.formatted(date: .abbreviated, time: .omitted))
					.font(.caption)
					.foregroundStyle(.secondary)
			}

			if let note = change.note {
				Text(note)
					.font(.subheadline)
					.foregroundStyle(.secondary)
			}
		}
		.contextMenu {
			Button(change.note == nil ? "Add Note" : "Edit Note", systemImage: "note.text") {
				note = change.note ?? ""
				isEditingNote = true
			}
		}
		.swipeActions(edge: .leading) {
			Button {
				note = change.note ?? ""
				isEditingNote = true
			} label: {
				Label("Note", systemImage: "note.text")
			}
		}
		.alert("Why?", isPresented: $isEditingNote) {
			TextField("What changed your mind", text: $note, axis: .vertical)
			Button("Cancel", role: .cancel) {}
			Button("Save") {
				ledger.setNote(note, on: change.id, of: beliefID)
			}
		}
	}
}
