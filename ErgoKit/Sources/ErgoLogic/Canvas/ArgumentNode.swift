//
//  ArgumentNode.swift
//  ErgoKit
//
//  Created by Adon Omeri on 6/11/2026.
//

import Foundation

/// A claim on the canvas. The app's own statement type conforms, which is why the canvas code is generic:
/// ErgoLogic can't see `Translation`, and the dependency goes the other way.
///
/// `position` is the centre of the box. Conforming types in the app need to be `nonisolated`.
public protocol ArgumentNode: Identifiable, Sendable where ID == UUID {
	var id: UUID { get }
	var position: CanvasPoint { get set }
	var english: String { get set }
	var logic: [LogicKeyboardEntry] { get set }

	/// Lets generic code create statements, for instance when text adds new lines
	init(id: UUID, position: CanvasPoint, english: String, logic: [LogicKeyboardEntry])
}

/// An arrow meaning "`premise` is a premise of `conclusion`". It is the only kind of link.
public protocol ArgumentLink: Identifiable, Sendable where ID == UUID {
	var id: UUID { get }
	var premise: UUID { get }
	var conclusion: UUID { get }

	init(id: UUID, premise: UUID, conclusion: UUID)
}

// MARK: - Plain values

/// The simplest statement. Reference implementation of the protocol, and what the tests use.
public struct ArgumentStatement: ArgumentNode, Hashable, Codable {
	public var id: UUID
	public var position: CanvasPoint
	public var english: String
	public var logic: [LogicKeyboardEntry]

	public init(id: UUID = UUID(), position: CanvasPoint = .zero, english: String = "", logic: [LogicKeyboardEntry] = []) {
		self.id = id
		self.position = position
		self.english = english
		self.logic = logic
	}
}

public struct ArgumentLinkValue: ArgumentLink, Hashable, Codable {
	public var id: UUID
	public var premise: UUID
	public var conclusion: UUID

	public init(id: UUID = UUID(), premise: UUID, conclusion: UUID) {
		self.id = id
		self.premise = premise
		self.conclusion = conclusion
	}
}
