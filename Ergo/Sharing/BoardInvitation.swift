//
//  BoardInvitation.swift
//  Ergo
//
//  Created by Adon Omeri on 7/11/2026.
//

import Foundation
import LinkPresentation
import SwiftUI
#if os(iOS)
	import UIKit
#else
	import AppKit
#endif

/// An invite link on its way out through the system share sheet.
struct BoardInvitation: Identifiable {
	let url: URL
	let title: String

	var id: URL {
		url
	}

	#if os(iOS)
		/// What the share sheet is told it's sharing
		func itemsConfiguration() -> UIActivityItemsConfiguration {
			let provider = NSItemProvider()
			provider.registerObject(url as NSURL, visibility: .all)

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
	#endif

	private nonisolated static func linkPreview(of url: URL, title: String) -> LPLinkMetadata {
		let metadata = LPLinkMetadata()
		metadata.originalURL = url
		metadata.url = url
		metadata.title = title
		return metadata
	}
}

// MARK: - The share sheet

#if os(iOS)
	/// The system share sheet. SwiftUI's `ShareLink` needs its link before it's tapped, and an invite is only made once
	/// Send Invite is tapped, so this wraps UIKit's one view controller and does nothing else.
	struct BoardInvitationSheet: UIViewControllerRepresentable {
		let invitation: BoardInvitation

		func makeUIViewController(context _: Context) -> UIActivityViewController {
			UIActivityViewController(activityItemsConfiguration: invitation.itemsConfiguration())
		}

		func updateUIViewController(_: UIActivityViewController, context _: Context) {}
	}
#else
	/// The Mac has no share sheet to wrap, but by now the invite exists, so `ShareLink` can take it
	struct BoardInvitationSheet: View {
		let invitation: BoardInvitation

		@Environment(\.dismiss)
		private var dismiss

		var body: some View {
			VStack(spacing: 16) {
				Label("Invite to \(invitation.title)", systemImage: "person.badge.plus")
					.font(.headline)

				HStack {
					Button("Copy Link", systemImage: "doc.on.doc") {
						NSPasteboard.general.clearContents()
						NSPasteboard.general.setString(invitation.url.absoluteString, forType: .string)
					}
					.accessibilityIdentifier("invitation.copy")

					ShareLink(item: invitation.url, subject: Text(invitation.title), preview: SharePreview(invitation.title))
						.accessibilityIdentifier("invitation.share")
				}

				Button("Done") {
					dismiss()
				}
				.keyboardShortcut(.defaultAction)
			}
			.padding(24)
			.frame(minWidth: 320)
		}
	}
#endif
