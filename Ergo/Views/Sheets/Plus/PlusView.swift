//
//  PlusView.swift
//  Ergo
//
//  Created by Adon Omeri on 10/11/2026.
//

import ErgoProtocol
import StoreKit
import SwiftUI

/// `PlusView` on its own, for when there's no navigation around it
struct PlusSheet: View {
	@Environment(NavigationManager.self)
	private var navigation

	var body: some View {
		NavigationStack {
			PlusView()
				.toolbar {
					ToolbarItem(placement: .topBarLeading) {
						Button(role: .close) {
							navigation.dismissSheet()
						}
						.accessibilityIdentifier("plus.close")
					}
				}
		}
	}
}

/// What the paid plan adds, and buying it. A plan belongs to an account, so buying needs one.
struct PlusView: View {
	@Environment(PurchaseStore.self)
	private var purchases

	@Environment(TranslationAccount.self)
	private var account

	var body: some View {
		if account.isSignedInHere {
			store
		} else {
			ContentUnavailableView(
				"Ergo Plus Needs an Account",
				systemImage: "person.crop.circle.badge.plus",
				description: Text("Sign in under Account in Settings, so your plan has somewhere to live.")
			)
		}
	}

	private var store: some View {
		SubscriptionStoreView(productIDs: PlanProducts.all) {
			PlusFeaturesView()
		}
		.storeButton(.visible, for: .restorePurchases)
		.onInAppPurchaseCompletion { _, result in
			if case let .success(.success(verification)) = result {
				await purchases.handle(verification)
			}
		}
		// A restore shows up here rather than as a purchase
		.onDisappear {
			Task {
				await purchases.uploadCurrent()
			}
		}
	}
}

private struct PlusFeaturesView: View {
	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			Text("Ergo Plus")
				.font(.largeTitle.bold())

			feature("A better model", "sparkles", "Answers and analysis on a stronger model, with far more of it each day.")
			feature("Shared boards", "person.2", "Work on an argument with other people.")
			feature("Long texts", "doc.plaintext", "Break down whole articles, a part at a time.")
			feature("The logic course", "graduationcap", "Every lesson, with exercises.")
		}
		.padding()
		.frame(maxWidth: .infinity, alignment: .leading)
	}

	private func feature(_ title: String, _ symbol: String, _ detail: String) -> some View {
		Label {
			VStack(alignment: .leading, spacing: 2) {
				Text(title)
					.font(.headline)
				Text(detail)
					.font(.subheadline)
					.foregroundStyle(.secondary)
			}
		} icon: {
			Image(systemName: symbol)
		}
	}
}
