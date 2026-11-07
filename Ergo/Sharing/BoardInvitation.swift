//
//  BoardInvitation.swift
//  Ergo
//
//  Created by Adon Omeri on 7/11/2026.
//

import ErgoProtocol
import Foundation
import LinkPresentation
import SharedWithYou
import SharedWithYouCore
import SwiftUI
import UIKit

/// An invite link on its way out through the system share sheet.
struct BoardInvitation: Identifiable {
	/// Whether Messages gets the board as a collaboration, with Apple's own permission picker.
	/// False leaves a plain link in the share sheet, which is the way out if this misbehaves on a device.
	static let usesMessagesCollaboration = true

	/// The last one made, for `CollaborationHandler`: Messages asks for a link after the sheet is already up
	static var latest: BoardInvitation?

	let board: Board.ID
	let url: URL
	let role: BoardRole
	let title: String
	let name: String

	var id: URL {
		url
	}

	/// What the share sheet is told it's sharing
	func itemsConfiguration() -> UIActivityItemsConfiguration {
		let provider = NSItemProvider()
		provider.registerObject(url as NSURL, visibility: .all)
		if Self.usesMessagesCollaboration {
			provider.registerObject(collaborationMetadata(), visibility: .all)
		}

		let configuration = UIActivityItemsConfiguration(itemProviders: [provider])
		let url = url
		let title = title
		// UIKit may ask from any thread, so this keeps away from the main actor
		configuration.metadataProvider = { @Sendable key in
			switch key {
				case .title:
					title
				case .linkPresentationMetadata:
					Self.linkPreview(of: url, title: title)
				default:
					nil
			}
		}
		return configuration
	}

	/// Apple's forums report that the collaboration doesn't appear without `defaultShareOptions`, so it always has them.
	/// The name is only shown to the person sending it, and the handle is left out so no email goes near it.
	private func collaborationMetadata() -> SWCollaborationMetadata {
		let metadata = SWCollaborationMetadata(localIdentifier: SWLocalCollaborationIdentifier(rawValue: BoardRecord.id(board)))
		metadata.title = title

		let options = [BoardRole.editor, .viewer].map { option in
			SWCollaborationOption(title: option.label, identifier: option.rawValue)
		}
		let picker = SWCollaborationOptionsPickerGroup(identifier: "role", options: options)
		picker.selectedOptionIdentifier = role.rawValue
		picker.title = "Permissions"
		metadata.defaultShareOptions = SWCollaborationShareOptions(optionsGroups: [picker])

		var initiator = PersonNameComponents()
		initiator.givenName = name
		metadata.initiatorNameComponents = initiator
		return metadata
	}

	private nonisolated static func linkPreview(of url: URL, title: String) -> LPLinkMetadata {
		let metadata = LPLinkMetadata()
		metadata.originalURL = url
		metadata.url = url
		metadata.title = title
		return metadata
	}

	// MARK: - From Messages

	/// The link for what was chosen in Apple's picker: the one already made when that's the same role, else a new one
	static func link(forBoard board: String, selected: String?) async throws -> URL {
		guard let latest, BoardRecord.id(latest.board) == board, let sync = AppDelegate.sync else {
			throw ServiceError(code: .invalidRequest, message: "Expected an invite being sent for this board")
		}

		let role = selected.flatMap(BoardRole.init(rawValue:)) ?? latest.role
		guard role != latest.role else { return latest.url }

		let invite = try await sync.invite(to: latest.board, role: role, title: latest.title, name: latest.name)
		Self.latest = BoardInvitation(board: latest.board, url: invite.url, role: role, title: latest.title, name: latest.name)
		return invite.url
	}
}

// MARK: - The share sheet

/// The system share sheet. SwiftUI's `ShareLink` can't take an activity configuration, and the configuration is the only
/// way to hand Messages a collaboration, so this wraps UIKit's one view controller and does nothing else.
struct BoardInvitationSheet: UIViewControllerRepresentable {
	let invitation: BoardInvitation

	func makeUIViewController(context _: Context) -> UIActivityViewController {
		UIActivityViewController(activityItemsConfiguration: invitation.itemsConfiguration())
	}

	func updateUIViewController(_: UIActivityViewController, context _: Context) {}
}

// MARK: - Collaboration actions

/// Messages calls this while a collaboration is being sent, and off the main actor, so it holds nothing and hops over.
///
/// It's here because Apple's API only talks to an object conforming to this protocol. Who someone is in Messages isn't
/// checked in this version (see `Plans/09-Sharing.md`): having the link is what gets them in, so adding people just succeeds.
final nonisolated class CollaborationHandler: NSObject, SWCollaborationActionHandler {
	func collaborationCoordinator(_: SWCollaborationCoordinator, handle action: SWStartCollaborationAction) {
		let metadata = action.collaborationMetadata
		let board = metadata.localIdentifier.rawValue
		let picker = metadata.userSelectedShareOptions?.optionsGroups.first as? SWCollaborationOptionsPickerGroup
		let selected = picker?.selectedOptionIdentifier

		// Only this task ever touches it again
		nonisolated(unsafe) let action = action
		Task { @MainActor in
			do {
				let url = try await BoardInvitation.link(forBoard: board, selected: selected)
				action.fulfill(using: url, collaborationIdentifier: SWCollaborationIdentifier(rawValue: board))
			} catch {
				action.fail()
			}
		}
	}

	func collaborationCoordinator(_: SWCollaborationCoordinator, handle action: SWUpdateCollaborationParticipantsAction) {
		action.fulfill()
	}
}
