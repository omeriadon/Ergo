//
//  LibrarySheets.swift
//  Ergo
//
//  Created by Adon Omeri on 10/11/2026.
//

import Defaults
import SwiftUI

/// The sheets that belong to the Library tab. See `NavigationManager.librarySheet`.
nonisolated enum LibrarySheet: Hashable, Identifiable, Codable, Defaults.Serializable {
	case addEntryToChat(AskAttachment.Content)

	var id: Self {
		self
	}
}

struct LibrarySheetContent: View {
	let sheet: LibrarySheet

	var body: some View {
		switch sheet {
			case let .addEntryToChat(content):
				AddToChatSheet(content: content)
		}
	}
}
