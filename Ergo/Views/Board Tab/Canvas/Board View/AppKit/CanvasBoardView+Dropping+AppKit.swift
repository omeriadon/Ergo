//
//  CanvasBoardView+Dropping+AppKit.swift
//  Ergo
//
//  Created by Adon Omeri on 14/11/2026.
//

#if os(macOS)
	import AppKit
	import ErgoLogic
	import ErgoShare

	/// Links and text dragged in from another app, such as a link out of Safari or a selection out of a PDF, become sources
	/// where they're let go. They're read the way the share extension reads what's shared, so a link dragged as text is still
	/// a link, and a file is nothing. The canvas is outlined in the accent while something it can take is over it.
	extension CanvasBoardView {
		/// Safari and most browsers put the page's title beside a dragged link under this type
		private static let linkTitleType = NSPasteboard.PasteboardType("public.url-name")

		/// What `init` registers for
		static let droppedTypes: [NSPasteboard.PasteboardType] = [.URL, .string]

		override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
			guard !isReadOnly, !droppedSources(from: sender.draggingPasteboard).isEmpty else { return [] }
			showsDropHighlight(true)
			return .copy
		}

		override func draggingExited(_: (any NSDraggingInfo)?) {
			showsDropHighlight(false)
		}

		override func draggingEnded(_: any NSDraggingInfo) {
			showsDropHighlight(false)
		}

		override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
			showsDropHighlight(false)
			let contents = droppedSources(from: sender.draggingPasteboard)
			guard !isReadOnly, !contents.isEmpty else { return false }
			let location = convert(sender.draggingLocation, from: nil)
			dropSources(contents, canvasTransform.canvas(location))
			return true
		}

		/// Web links first, each with the page's title when there's one link and the pasteboard has it. Otherwise the text,
		/// which is a link itself when it's only an address.
		private func droppedSources(from pasteboard: NSPasteboard) -> [BoardSource.Content] {
			let urls = (pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] ?? []).filter(\.isWebLink)
			if !urls.isEmpty {
				let title = urls.count == 1 ? pasteboard.string(forType: Self.linkTitleType) : nil
				return urls.compactMap { SharedItem.Content(url: $0, text: title) }.map(BoardSource.Content.init)
			}
			guard let shared = SharedItem.Content(url: nil, text: pasteboard.string(forType: .string)) else { return [] }
			return [BoardSource.Content(shared)]
		}

		/// An accent outline round the whole canvas. A layer's border draws over its sublayers, so it shows over the boxes.
		private func showsDropHighlight(_ isShown: Bool) {
			layer?.borderColor = accentColor
			layer?.borderWidth = isShown ? 3 : 0
		}
	}
#endif
