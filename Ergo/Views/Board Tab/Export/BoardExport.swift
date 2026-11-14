//
//  BoardExport.swift
//  Ergo
//
//  Created by Adon Omeri on 14/11/2026.
//

import CoreGraphics
import ErgoLogic
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

/// A board as a file to share: its outline as markdown, or the board as drawn as a PDF or a PNG. Each file is only made
/// when the share is chosen, in a folder of its own in the temporary directory, so the name can be the board's.
/// `ShareLink` takes one of the three items below, each with its own file type.
nonisolated struct BoardExport: Sendable {
	enum Format: Sendable {
		case markdown, pdf, image
	}

	let board: Board
	let format: Format

	/// What the share sheet shows, and the file's name without its extension
	var title: String {
		let cleaned = board.title
			.components(separatedBy: CharacterSet(charactersIn: "/\\:?*\"<>|").union(.newlines))
			.joined(separator: "-")
			.trimmingCharacters(in: .whitespaces)
		return String((cleaned.isEmpty ? "Board" : cleaned).prefix(60))
	}

	func file() async throws -> URL {
		let folder = FileManager.default.temporaryDirectory.appending(path: "Board Export/\(UUID().uuidString)", directoryHint: .isDirectory)
		try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

		switch format {
			case .markdown:
				let url = folder.appending(path: "\(title).md")
				try Data(markdown.utf8).write(to: url)
				return url
			case .pdf:
				let url = folder.appending(path: "\(title).pdf")
				try await BoardPictureFile.writePDF(of: board, to: url)
				return url
			case .image:
				let url = folder.appending(path: "\(title).png")
				try await BoardPictureFile.writePNG(of: board, to: url)
				return url
		}
	}

	/// The outline's text, from ErgoLogic so it reads like the outline view
	var markdown: String {
		let sources = board.sources.map { source in
			var text: String?
			if case let .text(body) = source.content {
				text = body
			}
			return ArgumentOutlineSource(
				title: source.title,
				link: source.link,
				text: text,
				members: board.members(of: source.id).map(\.id)
			)
		}
		return ArgumentOutlineMarkdown.text(title: board.title, map: board.map, sources: sources)
	}
}

// MARK: - Items

nonisolated struct BoardMarkdownExport: Transferable {
	let export: BoardExport

	static let markdown = UTType("net.daringfireball.markdown") ?? .plainText

	static var transferRepresentation: some TransferRepresentation {
		FileRepresentation(exportedContentType: markdown) { item in
			try await SentTransferredFile(item.export.file())
		}
	}
}

nonisolated struct BoardPDFExport: Transferable {
	let export: BoardExport

	static var transferRepresentation: some TransferRepresentation {
		FileRepresentation(exportedContentType: .pdf) { item in
			try await SentTransferredFile(item.export.file())
		}
	}
}

nonisolated struct BoardImageExport: Transferable {
	let export: BoardExport

	static var transferRepresentation: some TransferRepresentation {
		FileRepresentation(exportedContentType: .png) { item in
			try await SentTransferredFile(item.export.file())
		}
	}
}

/// Says why an export failed, worded like the compiler
nonisolated enum BoardExportError: LocalizedError {
	case couldNotDraw

	var errorDescription: String? {
		"Expected to draw the board, found nothing to write"
	}
}

/// `BoardPicture` as a file. `ImageRenderer` belongs to the main actor.
enum BoardPictureFile {
	/// Pixels on the longest side of a PNG, so a big board stays a sensible size in memory
	static let maximumPixels = 4096.0

	static func writePDF(of board: Board, to url: URL) throws {
		let renderer = ImageRenderer(content: BoardPicture(board: board))
		var wrote = false
		renderer.render { size, draw in
			var box = CGRect(origin: .zero, size: size)
			guard let context = unsafe CGContext(url as CFURL, mediaBox: &box, nil) else { return }
			context.beginPDFPage(nil)
			draw(context)
			context.endPDFPage()
			context.closePDF()
			wrote = true
		}
		guard wrote else { throw BoardExportError.couldNotDraw }
	}

	static func writePNG(of board: Board, to url: URL) throws {
		let picture = BoardPicture(board: board)
		let renderer = ImageRenderer(content: picture)
		renderer.scale = min(2, maximumPixels / max(picture.size.width, picture.size.height, 1))
		guard let image = renderer.cgImage,
		      let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
		else { throw BoardExportError.couldNotDraw }
		CGImageDestinationAddImage(destination, image, nil)
		guard CGImageDestinationFinalize(destination) else { throw BoardExportError.couldNotDraw }
	}
}

// MARK: - Menu

/// Export in the board's menu: the outline as markdown, or the board as drawn
struct BoardExportMenu: View {
	let board: Board

	var body: some View {
		Menu("Export", systemImage: "square.and.arrow.up") {
			link(BoardMarkdownExport(export: export(.markdown)), "Markdown Outline", systemImage: "list.bullet.indent")
			link(BoardPDFExport(export: export(.pdf)), "PDF", systemImage: "doc.richtext")
			link(BoardImageExport(export: export(.image)), "Image", systemImage: "photo")
		}
		.accessibilityIdentifier("board.export")
	}

	private func export(_ format: BoardExport.Format) -> BoardExport {
		BoardExport(board: board, format: format)
	}

	private func link(_ item: some Transferable, _ title: String, systemImage: String) -> some View {
		ShareLink(item: item, preview: SharePreview(BoardExport(board: board, format: .markdown).title)) {
			Label(title, systemImage: systemImage)
		}
	}
}
