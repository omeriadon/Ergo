//
//  BoardPicture.swift
//  Ergo
//
//  Created by Adon Omeri on 14/11/2026.
//

import ErgoLogic
import SwiftUI

/// The board as drawn, for exporting as a PDF or an image with `ImageRenderer`: regions, arrows with their heads, sources
/// and cards at their canvas positions. It's its own drawing rather than a snapshot of the canvas, since the canvas is
/// UIKit (AppKit on the Mac) and its boxes are blurs that `ImageRenderer` can't draw.
///
/// A board spread far apart is scaled down to fit `maximumSide`, so no export can be enormous.
struct BoardPicture: View {
	/// Points around what's on the board
	static let margin = 40.0

	/// The longest side, in points
	static let maximumSide = 4000.0

	let board: Board

	/// The part of the canvas that's drawn
	let bounds: CGRect

	/// Canvas units to points, at most 1
	let fitScale: CGFloat

	init(board: Board) {
		self.board = board
		let rects = board.occupiedRects
		if rects.isEmpty {
			bounds = CGRect(x: 0, y: 0, width: CanvasLayout.boxSize.width, height: CanvasLayout.boxSize.height)
		} else {
			let minX = rects.map(\.minX).min() ?? 0
			let minY = rects.map(\.minY).min() ?? 0
			let maxX = rects.map(\.maxX).max() ?? 0
			let maxY = rects.map(\.maxY).max() ?? 0
			bounds = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
				.insetBy(dx: -Self.margin, dy: -Self.margin)
		}
		fitScale = min(1, Self.maximumSide / max(bounds.width, bounds.height, 1))
	}

	/// What it comes out at, in points
	var size: CGSize {
		CGSize(width: (bounds.width * fitScale).rounded(.up), height: (bounds.height * fitScale).rounded(.up))
	}

	var body: some View {
		Canvas { context, _ in
			context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
			context.scaleBy(x: fitScale, y: fitScale)
			context.translateBy(x: -bounds.minX, y: -bounds.minY)
			drawRegions(in: context)
			drawArrows(in: context)
			for source in board.sources {
				drawSource(source, in: context)
			}
			for statement in board.statements {
				drawStatement(statement, in: context)
			}
		}
		.frame(width: size.width, height: size.height)
		.environment(\.colorScheme, .light)
	}

	// MARK: - Drawing

	private func drawRegions(in context: GraphicsContext) {
		for source in board.sources where !board.members(of: source.id).isEmpty {
			let path = Self.smoothPath(through: board.outline(of: source))
			context.fill(path, with: .color(Color.accent.opacity(0.07)))
			context.stroke(path, with: .color(Color.accent.opacity(0.6)), lineWidth: 2)
		}
	}

	private func drawArrows(in context: GraphicsContext) {
		var positions: [Statement.ID: CanvasPoint] = [:]
		for statement in board.statements {
			positions[statement.id] = statement.position
		}
		for link in board.links {
			guard let from = positions[link.premise], let to = positions[link.conclusion],
			      let curve = ArrowCurve(from: from, to: to)
			else { continue }
			context.stroke(curve.path, with: .color(.black.opacity(0.55)), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
		}
	}

	private func drawStatement(_ statement: Statement, in context: GraphicsContext) {
		let rect = box(at: statement.position)
		drawBox(rect, in: context)

		let english = statement.english.trimmingCharacters(in: .whitespacesAndNewlines)
		let text = Text(english.isEmpty ? "Empty statement" : String(english.prefix(200)))
			.font(.subheadline)
			.foregroundStyle(english.isEmpty ? Color.gray : Color.black)
		drawText(text, in: rect.insetBy(dx: 12, dy: 9), context: context)

		if board.links.contains(where: { $0.conclusion == statement.id && $0.premise != statement.id }) {
			let marker = context.resolve(Text("∴").font(.callout.weight(.semibold)).foregroundStyle(Color.gray))
			context.draw(marker, at: CGPoint(x: rect.minX + 12, y: rect.maxY - 9), anchor: .bottomLeading)
		}
	}

	private func drawSource(_ source: BoardSource, in context: GraphicsContext) {
		let rect = box(at: source.position)
		drawBox(rect, in: context)

		let symbol = source.link == nil ? "doc.text" : "safari"
		let text = Text("\(Image(systemName: symbol)) \(String(source.title.prefix(160)))")
			.font(.subheadline.weight(.semibold))
			.foregroundStyle(Color.black)
		drawText(text, in: rect.insetBy(dx: 12, dy: 9), context: context)
	}

	private func box(at center: CanvasPoint) -> CGRect {
		let size = CanvasLayout.boxSize
		return CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2, width: size.width, height: size.height)
	}

	private func drawBox(_ rect: CGRect, in context: GraphicsContext) {
		let shape = Path(roundedRect: rect, cornerRadius: StatementBoxView.corner, style: .continuous)
		context.fill(shape, with: .color(.white))
		context.stroke(shape, with: .color(.black.opacity(0.18)), lineWidth: 1)
	}

	/// Cut to the box, since a long statement would otherwise run out of it
	private func drawText(_ text: Text, in rect: CGRect, context: GraphicsContext) {
		context.drawLayer { layer in
			layer.clip(to: Path(rect))
			layer.draw(text, in: rect)
		}
	}

	/// The same smoothing `CanvasRegionLayer` gives a region's outline: a curve through the middle of each side
	static func smoothPath(through outline: [CanvasPoint]) -> Path {
		var path = Path()
		let count = outline.count
		guard count >= 3 else { return path }

		func middle(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
			CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
		}

		path.move(to: middle(outline[count - 1].point, outline[0].point))
		for index in 0 ..< count {
			let point = outline[index].point
			path.addQuadCurve(to: middle(point, outline[(index + 1) % count].point), control: point)
		}
		path.closeSubpath()
		return path
	}
}
