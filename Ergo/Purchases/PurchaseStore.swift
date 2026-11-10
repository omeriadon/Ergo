//
//  PurchaseStore.swift
//  Ergo
//
//  Created by Adon Omeri on 10/11/2026.
//

import ErgoProtocol
import StoreKit

/// Hands the App Store's transactions to the server, which is what decides the plan. A transaction is only finished once the
/// server has it, so a failed upload comes round again.
@MainActor
@Observable
final class PurchaseStore {
	@ObservationIgnored private let account: TranslationAccount
	@ObservationIgnored private var updates: Task<Void, Never>?

	init(account: TranslationAccount) {
		self.account = account
	}

	/// Renewals, and purchases made outside the app
	func start() {
		guard updates == nil else { return }
		updates = Task { [weak self] in
			for await result in Transaction.updates {
				await self?.handle(result)
			}
		}
		Task {
			await uploadCurrent()
		}
	}

	/// What's active now, for a purchase made while signed out or on another device
	func uploadCurrent() async {
		for await result in Transaction.currentEntitlements {
			await handle(result)
		}
	}

	func handle(_ result: VerificationResult<Transaction>) async {
		guard case let .verified(transaction) = result, PlanProducts.all.contains(transaction.productID) else { return }
		do {
			try await account.uploadPlan(transaction: result.jwsRepresentation)
			await transaction.finish()
		} catch {
			print("Couldn't upload the purchase: \(String(reflecting: type(of: error)))")
		}
	}
}
