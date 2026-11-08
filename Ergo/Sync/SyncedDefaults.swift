//
//  SyncedDefaults.swift
//  Ergo
//
//  Created by Adon Omeri on 5/11/2026.
//

import Defaults
import ErgoProtocol
import Foundation

// Which Defaults keys sync, and how their values become record fields and back.
//
// Synced: `boards` (`BoardRecord`, `StatementRecord`, `LinkRecord`), `scratchpads` (`ScratchpadRecord`, no child records), `bookmarks` (below) and the `SyncedSetting`s. Every other key stays on this
// device, so a new key is local until it's added here.

// MARK: - Coding

/// One encoder for every value. A value encoded two ways would look like an edit and sync again.
enum SyncCoding {
	static let encoder: JSONEncoder = {
		let encoder = JSONEncoder()
		encoder.outputFormatting = [.sortedKeys]
		encoder.dateEncodingStrategy = .iso8601
		return encoder
	}()

	static let decoder: JSONDecoder = {
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .iso8601
		return decoder
	}()

	static func value(_ value: some Encodable) throws -> JSONValue {
		try JSONValue(value, encoder: encoder)
	}

	static func decode<Value: Decodable>(_ type: Value.Type, from value: JSONValue) throws -> Value {
		try value.decode(type, decoder: decoder)
	}
}

// MARK: - Settings

extension SyncedSetting {
	/// The Defaults key behind each synced setting
	var key: Defaults._AnyKey {
		switch self {
			case .logicLetters:
				.logicLetters
			case .ditherEnabled:
				.ditherEnabled
			case .translationProvider:
				.translationProvider
			case .hapticsEnabled:
				.hapticsEnabled
			case .itemOfTheDayCategories:
				.itemOfTheDayCategories
		}
	}

	var localValue: JSONValue? {
		switch self {
			case .logicLetters:
				try? SyncCoding.value(Defaults[.logicLetters])
			case .ditherEnabled:
				try? SyncCoding.value(Defaults[.ditherEnabled])
			case .translationProvider:
				try? SyncCoding.value(Defaults[.translationProvider])
			case .hapticsEnabled:
				try? SyncCoding.value(Defaults[.hapticsEnabled])
			case .itemOfTheDayCategories:
				try? SyncCoding.value(Defaults[.itemOfTheDayCategories])
		}
	}

	/// Whether this version can read `value`. One it can't (from a newer app, or damaged) is never written.
	func canDecode(_ value: JSONValue) -> Bool {
		switch self {
			case .logicLetters:
				(try? SyncCoding.decode([String].self, from: value)) != nil
			case .ditherEnabled:
				(try? SyncCoding.decode(Bool.self, from: value)) != nil
			case .translationProvider:
				(try? SyncCoding.decode(Provider.self, from: value)) != nil
			case .hapticsEnabled:
				(try? SyncCoding.decode(Bool.self, from: value)) != nil
			case .itemOfTheDayCategories:
				(try? SyncCoding.decode([String].self, from: value)) != nil
		}
	}

	/// Skips a value that doesn't decode
	func write(_ value: JSONValue) {
		switch self {
			case .logicLetters:
				if let letters = try? SyncCoding.decode([String].self, from: value), letters != Defaults[.logicLetters] {
					Defaults[.logicLetters] = letters
				}
			case .ditherEnabled:
				if let enabled = try? SyncCoding.decode(Bool.self, from: value), enabled != Defaults[.ditherEnabled] {
					Defaults[.ditherEnabled] = enabled
				}
			case .translationProvider:
				if let provider = try? SyncCoding.decode(Provider.self, from: value), provider != Defaults[.translationProvider] {
					Defaults[.translationProvider] = provider
				}
			case .hapticsEnabled:
				if let enabled = try? SyncCoding.decode(Bool.self, from: value), enabled != Defaults[.hapticsEnabled] {
					Defaults[.hapticsEnabled] = enabled
				}
			case .itemOfTheDayCategories:
				if let categories = try? SyncCoding.decode([String].self, from: value), categories != Defaults[.itemOfTheDayCategories] {
					Defaults[.itemOfTheDayCategories] = categories
				}
		}
	}
}

// MARK: - Bookmarks

enum BookmarkRecord {
	/// Only the id syncs. The reference is rebuilt from this version's catalog, which might not have it.
	static func write(_ record: SyncRecord, catalog: CatalogIndex) {
		guard
			case let .bool(isPresent) = record.fields[SyncFieldName.present]?.value,
			let reference = catalog.resolve(record.id)
		else {
			return
		}

		let isBookmarked = Defaults[.bookmarks].contains { $0.id == reference.id }
		if isPresent, !isBookmarked {
			Defaults[.bookmarks].insert(reference)
		} else if !isPresent, isBookmarked {
			Defaults[.bookmarks] = Defaults[.bookmarks].filter { $0.id != reference.id }
		}
	}
}
