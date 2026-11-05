//
//  Translate.swift
//  ErgoKit
//
//  Created by Adon Omeri on 5/11/2026.
//

import ErgoTranslation
import Foundation

public struct TranslateRequest: Codable, Sendable, Hashable {
	public let id: UUID
	public let english: String
	public let provider: Provider

	/// `LogicLetters.resolved`, so the model writes the letters the app shows
	public let letters: [String]
	public let grammarVersion: Int

	public init(id: UUID, english: String, provider: Provider, letters: [String], grammarVersion: Int) {
		self.id = id
		self.english = english
		self.provider = provider
		self.letters = letters
		self.grammarVersion = grammarVersion
	}
}

public enum TranslateClientMessage: Codable, Sendable, Hashable {
	case translate(TranslateRequest)
	case cancel
}

public enum TranslateServerMessage: Codable, Sendable, Hashable {
	case event(TranslationEvent)
	case finished(Translation)
	case failed(ServiceError)
}
