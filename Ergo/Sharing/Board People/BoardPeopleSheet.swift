//
//  BoardPeopleSheet.swift
//  Ergo
//
//  Created by Adon Omeri on 7/11/2026.
//

import Defaults
import ErgoProtocol
import ErgoSync
import SwiftUI

/// The canvas's People button. Filled once the board is shared, and off until there's something on it to share.
struct BoardPeopleButton: View {
	let board: Board

	@Environment(NavigationManager.self)
	private var navigation

	@Environment(BoardStore.self)
	private var boardStore

	var body: some View {
		Button(boardStore.shares[board.id] == nil ? "Collaborate" : "People", systemImage: boardStore.shares[board.id] == nil ? "person.2" : "person.2.fill") {
			navigation.presentSheet(.boardPeople(board.id))
		}
		.disabled(board.isEmpty)
		.accessibilityIdentifier("board.peopleButton")
	}
}

/// Who's on a board. Only the owner can change that: everyone else gets the list and a way to leave.
struct BoardPeopleSheet: View {
	let board: Board.ID

	@Environment(NavigationManager.self)
	private var navigation

	@Environment(BoardStore.self)
	private var boardStore

	@Environment(SyncController.self)
	private var sync

	private var exists: Bool {
		boardStore.boards.contains { $0.id == board }
	}

	var body: some View {
		NavigationStack {
			content
				.toolbarTitleVire("People", "person.2")
				.toolbar {
					ToolbarItem(placement: .topBarLeading) {
						Button(role: .close) {
							navigation.dismissSheet()
						}
						.accessibilityIdentifier("people.close")
					}
				}
		}
		// Left, removed or deleted on another device, or this sheet was restored after that happened
		.onChange(of: exists, initial: true) {
			if !exists {
				navigation.dismissSheet()
			}
		}
	}

	@ViewBuilder
	private var content: some View {
		if !sync.isSignedIn {
			SharingNeedsAccountView()
		} else if let share = boardStore.shares[board], share.role != .owner {
			MemberPeopleList(board: board, share: share)
		} else {
			OwnerPeopleList(board: board, share: boardStore.shares[board])
		}
	}
}

// MARK: - Signed out

struct SharingNeedsAccountView: View {
	@Environment(NavigationManager.self)
	private var navigation

	var body: some View {
		ContentUnavailableView {
			Label("Sharing Needs an Account", systemImage: "person.crop.circle.badge.plus")
		} description: {
			Text("Sign in under Account in Settings, so other people's changes have somewhere to go.")
		} actions: {
			Button("Open Settings", systemImage: "gearshape") {
				navigation.presentSheet(.settings(id: "3refd"))
			}
			.buttonStyle(.glass)
			.accessibilityIdentifier("people.openSettings")
		}
	}
}

// MARK: - Owner

struct OwnerPeopleList: View {
	let board: Board.ID

	/// Nil until the board's first shared
	let share: BoardShare?

	@Environment(SyncController.self)
	private var sync

	@Environment(BoardStore.self)
	private var boardStore

	@Environment(NavigationManager.self)
	private var navigation

	@Environment(TranslationAccount.self)
	private var account

	@Default(.sharingName) private var name

	@State private var role = BoardRole.editor
	@State private var invitation: BoardInvitation?
	@State private var isSending = false
	@State private var problem: String?
	@State private var confirmingStop = false

	/// Only the first time, and it stays up while it's being typed in
	@State private var asksForName = Defaults[.sharingName].isEmpty

	var body: some View {
		List {
			inviteSection

			if let share {
				Section("People") {
					ForEach(share.sortedMembers) { member in
						OwnerMemberRow(member: member, change: { role in change(member, to: role) }, remove: { remove(member) })
					}
				}

				linksSection
			}
		}
		.animation(.smooth, value: problem)
		.animation(.smooth, value: share)
		.sheet(item: $invitation, onDismiss: sync.askToNotify) { invitation in
			BoardInvitationSheet(invitation: invitation)
				.presentationDetents([.medium, .large])
				.ignoresSafeArea()
		}
		.confirmationDialog("Stop sharing?", isPresented: $confirmingStop, titleVisibility: .visible) {
			Button("Stop Sharing", role: .destructive) {
				perform { try await sync.stopSharing(board) }
			}
			.accessibilityIdentifier("people.stopSharing.confirm")
		} message: {
			Text("Everyone else loses this board, and you keep it")
		}
		.onAppear(perform: fillInName)
	}

	/// What this account is already called on this board, from another device
	private func fillInName() {
		guard name.isEmpty, let share, let own = share.members.first(where: { $0.id == share.member }) else { return }
		name = own.name
		asksForName = false
	}

	// MARK: - Sections

	private var inviteSection: some View {
		Section {
			if asksForName {
				TextField("Your name", text: $name)
					.textContentType(.name)
					.submitLabel(.done)
					.accessibilityIdentifier("people.name")
			}

			Picker("Permission", selection: $role) {
				Text(BoardRole.editor.label)
					.tag(BoardRole.editor)
				Text(BoardRole.viewer.label)
					.tag(BoardRole.viewer)
			}
			.accessibilityIdentifier("people.role")

			Button(action: sendInvite) {
				HStack {
					Label("Send Invite", systemImage: "square.and.arrow.up")
					if isSending {
						Spacer()
						ProgressView()
					}
				}
			}
			.disabled(isSending || !SharingName.isValid(name))
			.accessibilityIdentifier("people.sendInvite")
		} footer: {
			inviteFooter
		}
	}

	@ViewBuilder
	private var inviteFooter: some View {
		if let problem = problem ?? SharingName.problem(with: name) {
			Text(problem)
				.foregroundStyle(.red)
		} else if asksForName {
			Text("Other people on this board see this name. Anyone with the link can join until it expires in 30 days.")
		} else {
			Text("Anyone with the link can join until it expires in 30 days.")
		}
	}

	private var linksSection: some View {
		Section {
			Button("Revoke Links", systemImage: "link.badge.plus") {
				perform { try await sync.revokeInvites(for: board) }
			}
			.accessibilityIdentifier("people.revokeLinks")

			Button("Stop Sharing", systemImage: "person.2.slash", role: .destructive) {
				confirmingStop = true
			}
			.accessibilityIdentifier("people.stopSharing")
		} footer: {
			Text("Revoking stops links that haven't been used. People who've joined stay.")
		}
	}

	// MARK: - Doing things

	private func sendInvite() {
		guard account.hasPlusFeatures else {
			navigation.presentSheet(.plus)
			return
		}
		guard let title = boardStore.boards.first(where: { $0.id == board })?.title else { return }
		let name = SharingName.cleaned(name)
		let role = role
		isSending = true
		problem = nil

		Task {
			defer { isSending = false }
			do {
				let invite = try await sync.invite(to: board, role: role, title: title, name: name)
				invitation = BoardInvitation(url: invite.url, title: title)
			} catch {
				problem = error.sharingMessage
			}
		}
	}

	private func change(_ member: BoardMember, to role: BoardRole) {
		guard member.role != role else { return }
		perform { try await sync.updateMember(member.id, of: board, role: role) }
	}

	private func remove(_ member: BoardMember) {
		perform { try await sync.removeMember(member.id, from: board) }
	}

	private func perform(_ work: @escaping () async throws -> Void) {
		problem = nil
		Task {
			do {
				try await work()
			} catch {
				problem = error.sharingMessage
			}
		}
	}
}
