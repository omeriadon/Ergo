//
//  BoardPeoplePreviews.swift
//  Ergo
//
//  Created by Adon Omeri on 8/11/2026.
//

import Defaults
import ErgoProtocol
import ErgoSync
import SwiftUI

// MARK: - Previews

let previewMembers = [
	BoardMember(id: UUID(), name: "Sam", role: .owner),
	BoardMember(id: UUID(), name: "Ada", role: .editor),
	BoardMember(id: UUID(), name: "Lin", role: .viewer),
]

#Preview("Not shared yet") {
	NavigationStack {
		OwnerPeopleList(board: UUID(), share: nil)
	}
	.environment(SyncController.preview(signedIn: true))
	.environment(BoardStore())
}

#Preview("Owner") {
	NavigationStack {
		OwnerPeopleList(board: UUID(), share: BoardShare(board: "", role: .owner, member: previewMembers[0].id, members: previewMembers))
	}
	.environment(SyncController.preview(signedIn: true))
	.environment(BoardStore())
}

#Preview("Member") {
	NavigationStack {
		MemberPeopleList(board: UUID(), share: BoardShare(board: "", role: .viewer, member: previewMembers[2].id, members: previewMembers))
	}
	.environment(BoardStore())
}

#Preview("Signed out") {
	NavigationStack {
		SharingNeedsAccountView()
	}
	.environment(NavigationManager())
}
