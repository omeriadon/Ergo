//
//  CanvasModels.swift
//  Ergo
//
//  Created by Adon Omeri on 6/11/2026.
//

import ErgoLogic

/// What one box shows. Compared before its SwiftUI is touched, so a box only redraws when this changes.
struct CanvasBoxModel: Equatable {
	let statement: Statement
	let relations: BoxRelations
	let appearance: BoxAppearance

	/// In the model so a role changing redraws the box. A hosted box can't read it from the app's environment.
	var isReadOnly = false
}

/// What one source shows, compared the same way
struct CanvasSourceModel: Equatable {
	let source: BoardSource
	let appearance: BoxAppearance
	var isReadOnly = false
}

/// A source and the cards in its region. Where they are is read from the views, so the shape follows a drag.
struct CanvasRegionModel: Equatable {
	let source: BoardSource.ID
	let members: [Statement.ID]
}
