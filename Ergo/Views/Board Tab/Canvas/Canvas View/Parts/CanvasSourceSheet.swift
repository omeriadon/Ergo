//
//  CanvasSourceSheet.swift
//  Ergo
//
//  Created by Adon Omeri on 8/11/2026.
//

import ErgoSync
import SwiftUI

/// The sheet for a new source, or for reading or editing one
struct CanvasSourceSheet: View {
	let sheet: SourceSheet
	let source: BoardSource?
	let isReadOnly: Bool
	let add: (BoardSource.Content) -> Void
	let update: (BoardSource.ID, BoardSource.Content) -> Void

	var body: some View {
		switch sheet {
			case .newText:
				SourceEditorSheet(kind: .text, save: add)
			case .newLink:
				SourceEditorSheet(kind: .link, save: add)
			case let .edit(id):
				if let source {
					if isReadOnly {
						SourceReaderSheet(source: source)
					} else {
						SourceEditorSheet(kind: source.link == nil ? .text : .link, content: source.content) { content in
							update(id, content)
						}
					}
				}
		}
	}
}
