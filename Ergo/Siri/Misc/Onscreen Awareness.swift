//
//  Onscreen Awareness.swift
//  Ergo
//
//  Created by Adon Omeri on 4/11/2026.
//

import AppIntents
import SwiftUI

extension View {
	func onscreenEntity<Entity: AppEntity>(
		_ type: Entity.Type,
		id: Entity.ID
	) -> some View {
		userActivity(
			"com.ergo.\(String(describing: type))",
			isActive: true
		) { activity in
			activity.appEntityIdentifier = EntityIdentifier(
				for: type,
				identifier: id
			)
		}
	}

	func listedEntity<Entity: AppEntity>(
		_ type: Entity.Type,
		id: Entity.ID
	) -> some View {
		appEntityIdentifier(
			EntityIdentifier(
				for: type,
				identifier: id
			)
		)
	}
}
