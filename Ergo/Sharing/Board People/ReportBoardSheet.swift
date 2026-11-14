//
//  ReportBoardSheet.swift
//  Ergo
//
//  Created by Adon Omeri on 10/11/2026.
//

import ErgoProtocol
import SwiftUI

/// Asks why a shared board is a problem and sends it to the server. Leaving the board, or the owner removing someone, is
/// how anyone stops seeing it, so this only tells whoever looks after Ergo.
struct ReportBoardSheet: View {
	let board: Board.ID

	@Environment(\.dismiss)
	private var dismiss

	@Environment(SyncController.self)
	private var sync

	@State private var reason = ""
	@State private var isSending = false

	private var canSend: Bool {
		!isSending && reason.trimmedNonEmpty != nil
	}

	var body: some View {
		NavigationStack {
			Form {
				Section {
					TextField("What's wrong with this board?", text: $reason, axis: .vertical)
						.lineLimit(4 ... 10)
						.accessibilityIdentifier("report.reason")
				} footer: {
					footer
				}
			}
			.navigationTitle("Report Board")
			.toolbarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .sheetDismissal) {
					Button(role: .cancel) {
						dismiss()
					}
					.accessibilityIdentifier("report.cancel")
					.keyboardShortcut(.cancelAction)
				}
				ToolbarItem(placement: .sheetConfirmation) {
					Button("Send", role: .confirm, action: send)
						.disabled(!canSend)
						.accessibilityIdentifier("report.send")
				}
			}
		}
		.onChange(of: reason) {
			if reason.count > ReportBoard.reasonCharacters {
				reason = String(reason.prefix(ReportBoard.reasonCharacters))
			}
		}
		.interactiveDismissDisabled(isSending)
	}

	private var footer: some View {
		Text("\(reason.count) of \(ReportBoard.reasonCharacters). Whoever looks after Ergo reads this. To stop seeing the board, leave it.")
	}

	private func send() {
		isSending = true
		Task {
			defer { isSending = false }
			do {
				try await sync.report(board, reason: reason)
				StatusBadgeManager.shared.addBadge(id: UUID(), title: "Report Sent", priority: 3, view: .success)
				dismiss()
			} catch {
				StatusBadgeManager.shared.present(error: error, title: "Couldn't Send Report")
			}
		}
	}
}
