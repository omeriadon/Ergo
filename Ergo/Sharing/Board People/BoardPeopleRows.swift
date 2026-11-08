//
//  BoardPeopleRows.swift
//  Ergo
//
//  Created by Adon Omeri on 8/11/2026.
//

import Defaults
import ErgoProtocol
import ErgoSync
import SwiftUI

/// The owner can't change or remove themselves, so their own row is just a row
struct OwnerMemberRow: View {
	let member: BoardMember
	let change: (BoardRole) -> Void
	let remove: () -> Void

	var body: some View {
		if member.role == .owner {
			PersonRow(member: member)
		} else {
			LabeledContent(member.name) {
				Menu(member.role.label) {
					Button(BoardRole.editor.label, systemImage: "pencil") { change(.editor) }
						.accessibilityIdentifier("people.member.canEdit")
					Button(BoardRole.viewer.label, systemImage: "eye") { change(.viewer) }
						.accessibilityIdentifier("people.member.viewOnly")
					Divider()
					Button("Remove", systemImage: "person.badge.minus", role: .destructive, action: remove)
						.accessibilityIdentifier("people.member.remove")
				}
				.accessibilityIdentifier("people.member.menu")
			}
			.swipeActions {
				Button("Remove", systemImage: "person.badge.minus", role: .destructive, action: remove)
			}
		}
	}
}

// MARK: - Member

struct MemberPeopleList: View {
	let board: Board.ID
	let share: BoardShare

	@Environment(BoardStore.self)
	private var boardStore

	@State private var confirmingLeave = false

	var body: some View {
		List {
			Section("People") {
				ForEach(share.sortedMembers) { member in
					PersonRow(member: member)
				}
			}

			Section {
				Button("Leave Board", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
					confirmingLeave = true
				}
				.accessibilityIdentifier("people.leave")
			}
		}
		.confirmationDialog("Leave this board?", isPresented: $confirmingLeave, titleVisibility: .visible) {
			Button("Leave", role: .destructive) {
				// Leaving is deleting: this account's tombstone on a board it doesn't own
				boardStore.delete([board])
			}
			.accessibilityIdentifier("people.leave.confirm")
		} message: {
			Text("It goes from your devices, and you'd need a new link to come back")
		}
	}
}

struct PersonRow: View {
	let member: BoardMember

	var body: some View {
		LabeledContent(member.name, value: member.role.label)
	}
}
