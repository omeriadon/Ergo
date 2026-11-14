//
//  SyncController+Preview.swift
//  Ergo
//
//  Created by Adon Omeri on 5/11/2026.
//

import Defaults
import ErgoClient
import ErgoLogic
import ErgoProtocol
import SwiftUI
#if os(iOS)
	import UIKit
#endif

// MARK: - Previews

/// Not debug-only: the previews that use it are compiled in release builds too
extension SyncController {
	static func preview(signedIn: Bool, email: String? = nil, status: Status = .notSynced) -> SyncController {
		let account = TranslationAccount(
			signedIn: signedIn ? SignedInAccount(server: ServerEnvironment.productionURL, id: UUID(), email: email) : nil
		)
		let sync = SyncController(account: account, boardStore: BoardStore(), scratchpadStore: ScratchpadStore(), catalog: CatalogStore())
		sync.seed(status)
		return sync
	}

	/// Shows `status` without syncing
	private func seed(_ status: Status) {
		switch status {
			case .notSynced:
				break
			case .syncing:
				_ = schedule.apply(.requested)
			case let .upToDate(date):
				outcome = .succeeded(date)
			case .waitingForNetwork:
				outcome = .failed("", unreachable: true)
			case let .failed(message):
				outcome = .failed(message, unreachable: false)
		}
	}
}
