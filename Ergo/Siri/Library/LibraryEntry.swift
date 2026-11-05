//
//  LibraryEntry.swift
//  Ergo
//
//  Created by Adon Omeri on 4/11/2026.
//

// LibraryEntry.swift

import AppIntents

@UnionValue
enum LibraryEntry {
	case bias(BiasEntity)
	case concept(ConceptEntity)
	case fallacy(FallacyEntity)
	case paradox(ParadoxEntity)
	case razor(RazorEntity)
	case argument(ArgumentEntity)
	case philosopher(PhilosopherEntity)
	case symbol(SymbolEntity)
}

extension LibraryEntry {
	var category: LibraryContent {
		switch self {
			case .bias:
				.biases

			case .concept:
				.concepts

			case .fallacy:
				.fallacies

			case .paradox:
				.paradoxes

			case .razor:
				.razors

			case .argument:
				.arguments

			case .philosopher:
				.philosophers

			case .symbol:
				.symbols
		}
	}

	var id: String {
		switch self {
			case let .bias(entity):
				entity.id

			case let .concept(entity):
				entity.id

			case let .fallacy(entity):
				entity.id

			case let .paradox(entity):
				entity.id

			case let .razor(entity):
				entity.id

			case let .argument(entity):
				entity.id

			case let .philosopher(entity):
				entity.id

			case let .symbol(entity):
				entity.id
		}
	}

	var name: String {
		switch self {
			case let .bias(entity):
				entity.name

			case let .concept(entity):
				entity.name

			case let .fallacy(entity):
				entity.name

			case let .paradox(entity):
				entity.name

			case let .razor(entity):
				entity.name

			case let .argument(entity):
				entity.name

			case let .philosopher(entity):
				entity.name

			case let .symbol(entity):
				entity.name
		}
	}
}
