//
//  SourceBoxView.swift
//  Ergo
//
//  Created by Adon Omeri on 7/11/2026.
//

import ErgoLogic
import SwiftUI

/// What a source can do, handed in by the canvas
struct SourceActions {
	var select: () -> Void

	/// Opens a link in the browser, or the editor for text
	var open: () -> Void
	var edit: () -> Void
	var breakDown: () -> Void
	var delete: () -> Void

	/// Whole grid steps, right and down are positive
	var nudge: (_ columns: Int, _ rows: Int) -> Void
}

/// A source as a sheet of paper with a folded corner, so it never reads as a claim. Drawn at `CanvasLayout.boxSize`, like a
/// statement, so finding room for it works the same. Moving it is done around it by `CanvasBoardView`.
struct CanvasSourceBox: View {
	let model: CanvasSourceModel
	let actions: SourceActions

	private var source: BoardSource {
		model.source
	}

	var body: some View {
		SourceBoxView(source: source, appearance: model.appearance, annotationCount: model.annotationCount)
			.equatable()
			.onTapGesture(perform: actions.select)
			.simultaneousGesture(TapGesture(count: 2).onEnded(actions.open))
			.contextMenu { menu }
			.modifier(SourceSpeech(source: source, isSelected: model.appearance == .selected, annotationCount: model.annotationCount))
			.modifier(SourceAccessibilityActions(isLink: source.link != nil, isReadOnly: model.isReadOnly, actions: actions))
			.modifier(BoxMovesModifier(nudge: actions.nudge, isReadOnly: model.isReadOnly))
	}

	@ViewBuilder
	private var menu: some View {
		if let link = source.link {
			Button("Open in Browser", systemImage: "safari", action: actions.open)
			Button("Copy Link", systemImage: "link") {
				UIPasteboard.general.url = link
			}
		}
		if !model.isReadOnly {
			Button("Edit", systemImage: "square.and.pencil", action: actions.edit)
			Button("Break Down", systemImage: "arrow.triangle.branch", action: actions.breakDown)
			Button("Delete", systemImage: "trash", role: .destructive, action: actions.delete)
		} else if source.link == nil {
			Button("Open", systemImage: "doc.text", action: actions.open)
		}
	}
}

// MARK: - Accessibility

private struct SourceSpeech: ViewModifier {
	let source: BoardSource
	let isSelected: Bool
	let annotationCount: Int

	private var value: String {
		let kind = source.link == nil ? "Text" : "Web link"
		guard annotationCount > 0 else { return kind }
		return "\(kind). \(annotationCount == 1 ? "1 annotation" : "\(annotationCount) annotations")"
	}

	func body(content: Content) -> some View {
		content
			.accessibilityElement(children: .ignore)
			.accessibilityLabel(source.title)
			.accessibilityValue(value)
			.accessibilityHint("Double tap to select")
			.accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
			.accessibilityIdentifier("board.source.\(source.id.uuidString)")
	}
}

private struct SourceAccessibilityActions: ViewModifier {
	let isLink: Bool
	let isReadOnly: Bool
	let actions: SourceActions

	func body(content: Content) -> some View {
		if isReadOnly {
			content
				.accessibilityAction(.default, actions.select)
				.accessibilityAction(named: Text(isLink ? "Open in Browser" : "Open"), actions.open)
		} else {
			content
				.accessibilityAction(.default, actions.select)
				.accessibilityAction(named: Text(isLink ? "Open in Browser" : "Edit"), actions.open)
				.accessibilityAction(named: Text("Break Down"), actions.breakDown)
				.accessibilityAction(named: Text("Delete"), actions.delete)
		}
	}
}

// MARK: - The box

struct SourceBoxView: View, Equatable {
	private static let shape = FoldedSheet(corner: StatementBoxView.corner, fold: 22)

	let source: BoardSource
	let appearance: BoxAppearance
	var annotationCount = 0

	var body: some View {
		VStack(alignment: .leading, spacing: 5) {
			Label(source.link == nil ? "Text" : "Web Link", systemImage: source.link == nil ? "doc.text" : "safari")
				.font(.caption.weight(.semibold))
				.foregroundStyle(.tint)

			Text(source.title)
				.font(.subheadline.weight(.medium))
				.lineLimit(source.link == nil ? 3 : 2)
				.frame(maxWidth: .infinity, alignment: .leading)

			if let host = source.link?.host() {
				Text(host)
					.font(.caption)
					.foregroundStyle(.secondary)
					.lineLimit(1)
			}

			Spacer(minLength: 0)
		}
		.padding(.horizontal, 12)
		.padding(.vertical, 9)
		.frame(width: CanvasLayout.boxSize.width, height: CanvasLayout.boxSize.height, alignment: .topLeading)
		// The box is a fixed size on the canvas, and zooming is how it gets bigger, so type doesn't grow with Dynamic Type
		.dynamicTypeSize(...DynamicTypeSize.large)
		.background {
			BackdropBlur(radius: 4)
				.overlay(Color.accent.opacity(0.1))
				.clipShape(Self.shape)
		}
		.overlay { outline }
		.overlay(alignment: .bottomTrailing) {
			AnnotationBadge(count: annotationCount)
				.padding(8)
		}
		.overlay(alignment: .topTrailing) {
			FoldFlap(fold: Self.shape.fold)
				.fill(Color.accent.opacity(0.35))
				.frame(width: Self.shape.fold, height: Self.shape.fold)
		}
		.opacity(appearance == .unavailable ? 0.4 : 1)
		.contentShape(Self.shape)
		.contentShape(.contextMenuPreview, Self.shape)
	}

	@ViewBuilder
	private var outline: some View {
		switch appearance {
			case .selected, .connectSource:
				Self.shape.stroke(Color.accent, lineWidth: 3)
			case .normal, .unavailable:
				Self.shape.stroke(Color.accent.opacity(0.5), lineWidth: 1)
		}
	}
}

/// A rounded rectangle with its top right corner cut off, for the fold
struct FoldedSheet: InsettableShape {
	let corner: CGFloat
	let fold: CGFloat
	var inset: CGFloat = 0

	func inset(by amount: CGFloat) -> Self {
		var shape = self
		shape.inset += amount
		return shape
	}

	func path(in rect: CGRect) -> Path {
		let rect = rect.insetBy(dx: inset, dy: inset)
		var path = Path()
		path.move(to: CGPoint(x: rect.minX + corner, y: rect.minY))
		path.addLine(to: CGPoint(x: rect.maxX - fold, y: rect.minY))
		path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + fold))
		path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY), tangent2End: CGPoint(x: rect.minX, y: rect.maxY), radius: corner)
		path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.maxY), tangent2End: CGPoint(x: rect.minX, y: rect.minY), radius: corner)
		path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY), tangent2End: CGPoint(x: rect.minX + corner, y: rect.minY), radius: corner)
		path.closeSubpath()
		return path
	}
}

/// The corner that's been folded over
struct FoldFlap: Shape {
	let fold: CGFloat

	func path(in rect: CGRect) -> Path {
		var path = Path()
		path.move(to: CGPoint(x: rect.minX, y: rect.minY))
		path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
		path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.maxY))
		path.closeSubpath()
		return path
	}
}
