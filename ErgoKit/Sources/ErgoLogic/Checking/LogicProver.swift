//
//  LogicProver.swift
//  ErgoKit
//
//  Created by Adon Omeri on 7/11/2026.
//

import Foundation

/// Decides everything a truth table can't: □ ◇, ∀ ∃, identity and sets, in any mix. A semantic tableau: it tries to
/// build a situation where the given statements hold. If every attempt contradicts itself, no such situation exists.
/// If one finishes, it's a real model. Neither answer is ever a guess, and running out of steps says so instead.
///
/// - □ ◇ are S5: every possible world can see every other.
/// - Things exist in every world, there's always at least one, and a letter names the same thing in every world.
/// - A set is the things that are in it, which can differ between worlds. Sets hold things, never other sets.
struct LogicProver {
	enum Outcome: Equatable {
		case impossible
		case possible
		case unknown
	}

	/// Counts work rather than time, so the same logic always gets the same answer
	private static let stepLimit = 3_000_000

	/// Letters from here up are ∀ and ∃'s own
	private static let firstBound = 1000

	/// Letters from here up are things made up during the search
	private static let firstMadeUp = 1_000_000

	/// Everything being checked together, so a letter is the same sort in all of it
	let context: [LogicFormula]

	/// Whether there's a situation where all of `truths` hold and all of `falsehoods` don't
	func check(truths: [LogicFormula], falsehoods: [LogicFormula] = []) -> Outcome {
		var sorts = LogicSorts()
		var next = Self.firstBound

		func bound(_ formula: LogicFormula) -> LogicFormula {
			let formula = formula.uniquelyBound(next: &next, sorts: &sorts)
			sorts.add(formula)
			return formula
		}

		context.forEach { _ = bound($0) }
		let (truths, falsehoods) = (truths.map(bound), falsehoods.map(bound))
		guard sorts.conflict == nil else { return .unknown }

		var translator = Translator(sorts: sorts, firstBound: Self.firstBound, nextMadeUp: Self.firstMadeUp)

		do {
			let positive = try truths.map { try translator.translate($0, positive: true) }
			let negative = try falsehoods.map { try translator.translate($0, positive: false) }
			let formulas = (positive + negative).map(\.miniscoped)

			var search = Search(firstMadeUp: Self.firstMadeUp, stepLimit: Self.stepLimit)
			search.maximumThings = Self.smallModelBound(of: formulas)
			return try search.isPossible(formulas) ? .possible : .impossible
		} catch {
			return .unknown
		}
	}

	/// With only one-place predicates and no □ ◇, anything possible is possible with at most q·2^k things
	/// (Löwenheim–Behmann), for k predicates and q quantifiers and names. Searching that far is a full answer.
	private static func smallModelBound(of formulas: [Node]) -> Int? {
		var measure = Measure()
		formulas.forEach { measure.add($0) }

		guard measure.isMonadic, measure.predicates.count <= 16 else { return nil }
		return max(1, measure.quantifiers + measure.names.count) << measure.predicates.count
	}
}

// MARK: - Formulas

/// What the search works on, with every negation pushed down onto a fact
private indirect enum Node: Hashable {
	case top
	case bottom
	case fact(Fact, Bool)
	case same(Thing, Thing, Bool)
	case and(Node, Node)
	case or(Node, Node)
	case always(Node)
	case sometimes(Node)
	case all(Int, Node)
	case some(Int, Node)
}

private enum Thing: Hashable {
	case bound(Int)
	case name(Int)
}

private struct Fact: Hashable {
	enum Kind: Hashable {
		case statement(Int)
		case predicate(Int)
		case set(Int)
	}

	let kind: Kind
	var things: [Thing]
}

private func both(_ left: Node, _ right: Node) -> Node {
	switch (left, right) {
		case (.bottom, _), (_, .bottom): .bottom
		case let (.top, other), let (other, .top): other
		default: .and(left, right)
	}
}

private func either(_ left: Node, _ right: Node) -> Node {
	switch (left, right) {
		case (.top, _), (_, .top): .top
		case let (.bottom, other), let (other, .bottom): other
		default: .or(left, right)
	}
}

private extension Node {
	var negated: Node {
		switch self {
			case .top: .bottom
			case .bottom: .top
			case let .fact(fact, value): .fact(fact, !value)
			case let .same(left, right, value): .same(left, right, !value)
			case let .and(left, right): either(left.negated, right.negated)
			case let .or(left, right): both(left.negated, right.negated)
			case let .always(value): .sometimes(value.negated)
			case let .sometimes(value): .always(value.negated)
			case let .all(letter, body): .some(letter, body.negated)
			case let .some(letter, body): .all(letter, body.negated)
		}
	}

	func mentions(_ letter: Int) -> Bool {
		switch self {
			case .top, .bottom:
				false
			case let .fact(fact, _):
				fact.things.contains(.bound(letter))
			case let .same(left, right, _):
				left == .bound(letter) || right == .bound(letter)
			case let .and(left, right), let .or(left, right):
				left.mentions(letter) || right.mentions(letter)
			case let .always(value), let .sometimes(value):
				value.mentions(letter)
			case let .all(other, body), let .some(other, body):
				other != letter && body.mentions(letter)
		}
	}

	func replacing(_ letter: Int, with name: Int) -> Node {
		func swap(_ thing: Thing) -> Thing {
			thing == .bound(letter) ? .name(name) : thing
		}

		switch self {
			case .top, .bottom:
				return self
			case let .fact(fact, value):
				return .fact(Fact(kind: fact.kind, things: fact.things.map(swap)), value)
			case let .same(left, right, value):
				return .same(swap(left), swap(right), value)
			case let .and(left, right):
				return .and(left.replacing(letter, with: name), right.replacing(letter, with: name))
			case let .or(left, right):
				return .or(left.replacing(letter, with: name), right.replacing(letter, with: name))
			case let .always(value):
				return .always(value.replacing(letter, with: name))
			case let .sometimes(value):
				return .sometimes(value.replacing(letter, with: name))
			case let .all(other, body):
				return other == letter ? self : .all(other, body.replacing(letter, with: name))
			case let .some(other, body):
				return other == letter ? self : .some(other, body.replacing(letter, with: name))
		}
	}

	/// Pushes quantifiers as far in as they go, since separate small ones need far less searching than nested ones
	var miniscoped: Node {
		switch self {
			case .top, .bottom, .fact, .same:
				return self
			case let .and(left, right):
				return both(left.miniscoped, right.miniscoped)
			case let .or(left, right):
				return either(left.miniscoped, right.miniscoped)
			case let .always(value):
				return .always(value.miniscoped)
			case let .sometimes(value):
				return .sometimes(value.miniscoped)
			case let .all(letter, body):
				let body = body.miniscoped
				guard body.mentions(letter) else { return body }
				switch body {
					case let .and(left, right):
						return both(Node.all(letter, left).miniscoped, Node.all(letter, right).miniscoped)
					case let .or(left, right) where !right.mentions(letter):
						return either(Node.all(letter, left).miniscoped, right)
					case let .or(left, right) where !left.mentions(letter):
						return either(left, Node.all(letter, right).miniscoped)
					default:
						return .all(letter, body)
				}
			case let .some(letter, body):
				let body = body.miniscoped
				guard body.mentions(letter) else { return body }
				switch body {
					case let .or(left, right):
						return either(Node.some(letter, left).miniscoped, Node.some(letter, right).miniscoped)
					case let .and(left, right) where !right.mentions(letter):
						return both(Node.some(letter, left).miniscoped, right)
					case let .and(left, right) where !left.mentions(letter):
						return both(left, Node.some(letter, right).miniscoped)
					default:
						return .some(letter, body)
				}
		}
	}
}

private struct Measure {
	var isMonadic = true
	var quantifiers = 0
	var predicates: Set<Fact.Kind> = []
	var names: Set<Int> = []

	mutating func add(_ node: Node) {
		switch node {
			case .top, .bottom:
				break
			case let .fact(fact, _):
				if case .statement = fact.kind {
					return
				}
				predicates.insert(fact.kind)
				if fact.things.count > 1 {
					isMonadic = false
				}
				fact.things.forEach { add($0) }
			case let .same(left, right, _):
				add(left)
				add(right)
			case let .and(left, right), let .or(left, right):
				add(left)
				add(right)
			case let .always(value), let .sometimes(value):
				isMonadic = false
				add(value)
			case let .all(_, body), let .some(_, body):
				quantifiers += 1
				add(body)
		}
	}

	private mutating func add(_ thing: Thing) {
		if case let .name(name) = thing {
			names.insert(name)
		}
	}
}

// MARK: - Translating

private struct Translator {
	/// A ∀ or ∃ over sets, which is second order
	struct Unsupported: Error {}

	let sorts: LogicSorts
	let firstBound: Int
	var nextMadeUp: Int

	mutating func translate(_ formula: LogicFormula, positive: Bool) throws -> Node {
		switch formula {
			case let .atom(slot):
				return .fact(Fact(kind: .statement(slot), things: []), positive)
			case .truth:
				return positive ? .top : .bottom
			case let .not(value):
				return try translate(value, positive: !positive)
			case let .and(left, right):
				let (left, right) = try (translate(left, positive: positive), translate(right, positive: positive))
				return positive ? both(left, right) : either(left, right)
			case let .or(left, right):
				let (left, right) = try (translate(left, positive: positive), translate(right, positive: positive))
				return positive ? either(left, right) : both(left, right)
			case let .implies(left, right):
				let (left, right) = try (translate(left, positive: !positive), translate(right, positive: positive))
				return positive ? either(left, right) : both(left, right)
			case let .iff(left, right):
				return try equivalent(left, right, positive: positive)
			case let .xor(left, right):
				return try equivalent(left, right, positive: !positive)
			case let .necessarily(value):
				let value = try translate(value, positive: positive)
				return positive ? .always(value) : .sometimes(value)
			case let .possibly(value):
				let value = try translate(value, positive: positive)
				return positive ? .sometimes(value) : .always(value)
			case let .forAll(letter, body):
				guard !sorts.isSet(letter) else { throw Unsupported() }
				let body = try translate(body, positive: positive)
				return positive ? .all(letter, body) : .some(letter, body)
			case let .exists(letter, body):
				guard !sorts.isSet(letter) else { throw Unsupported() }
				let body = try translate(body, positive: positive)
				return positive ? .some(letter, body) : .all(letter, body)
			case let .predicate(slot, terms):
				return try .fact(Fact(kind: .predicate(slot), things: terms.map(thing)), positive)
			case let .relation(relation, left, right):
				let node = try translate(relation, left, right)
				return positive ? node : node.negated
		}
	}

	private mutating func equivalent(_ left: LogicFormula, _ right: LogicFormula, positive: Bool) throws -> Node {
		let (leftTrue, rightTrue) = try (translate(left, positive: true), translate(right, positive: true))
		let (leftFalse, rightFalse) = (leftTrue.negated, rightTrue.negated)
		return positive
			? either(both(leftTrue, rightTrue), both(leftFalse, rightFalse))
			: either(both(leftTrue, rightFalse), both(leftFalse, rightTrue))
	}

	private mutating func translate(_ relation: LogicRelation, _ left: LogicTerm, _ right: LogicTerm) throws -> Node {
		switch relation {
			case .equal:
				return try equal(left, right)
			case .notEqual:
				return try equal(left, right).negated
			case .member:
				return try contains(right, thing(left))
			case .notMember:
				return try contains(right, thing(left)).negated
			case .subset:
				return try subset(left, right)
			case .properSubset:
				let witness = madeUpLetter()
				let member = Thing.bound(witness)
				return try both(subset(left, right), .some(witness, both(contains(right, member), contains(left, member).negated)))
		}
	}

	/// Sets are equal when they have the same things in them
	private mutating func equal(_ left: LogicTerm, _ right: LogicTerm) throws -> Node {
		if case let .variable(first) = left, case let .variable(second) = right, !sorts.isSet(first), !sorts.isSet(second) {
			return try .same(thing(left), thing(right), true)
		}

		let letter = madeUpLetter()
		let member = Thing.bound(letter)
		let (inLeft, inRight) = try (contains(left, member), contains(right, member))
		return .all(letter, either(both(inLeft, inRight), both(inLeft.negated, inRight.negated)))
	}

	private mutating func subset(_ left: LogicTerm, _ right: LogicTerm) throws -> Node {
		let letter = madeUpLetter()
		let member = Thing.bound(letter)
		return try .all(letter, either(contains(left, member).negated, contains(right, member)))
	}

	private func contains(_ set: LogicTerm, _ member: Thing) throws -> Node {
		switch set {
			case let .variable(slot):
				guard slot < firstBound else { throw Unsupported() }
				return .fact(Fact(kind: .set(slot), things: [member]), true)
			case .emptySet:
				return .bottom
			case let .union(left, right):
				return try either(contains(left, member), contains(right, member))
			case let .intersection(left, right):
				return try both(contains(left, member), contains(right, member))
		}
	}

	private func thing(_ term: LogicTerm) throws -> Thing {
		guard case let .variable(slot) = term else { throw Unsupported() }
		return slot < firstBound ? .name(slot) : .bound(slot)
	}

	private mutating func madeUpLetter() -> Int {
		nextMadeUp += 1
		return nextMadeUp
	}
}

// MARK: - Searching

private struct OutOfSteps: Error {}

private struct Search {
	let firstMadeUp: Int
	let stepLimit: Int

	/// Past this many things, anything still possible would already have been found
	var maximumThings: Int?

	private var steps = 0

	/// How many things this pass may use
	private var thingLimit = 1

	/// A pass stopped short of adding a thing, so it failing doesn't prove anything
	private var reachedLimit = false

	init(firstMadeUp: Int, stepLimit: Int) {
		self.firstMadeUp = firstMadeUp
		self.stepLimit = stepLimit
	}

	mutating func isPossible(_ formulas: [Node]) throws -> Bool {
		var measure = Measure()
		formulas.forEach { measure.add($0) }

		// New names are numbered well past the letters ∀ and ∃ made up during translation
		var branch = Branch(nextName: firstMadeUp * 2)
		for name in measure.names.sorted() {
			branch.names.append(name)
		}
		if branch.names.isEmpty {
			branch.names.append(branch.makeName())
		}

		for formula in formulas {
			branch.add(formula, world: 0)
		}

		// One thing, then two, and so on, which finds the smallest model. Going deep first can miss one forever.
		thingLimit = branch.distinctThings.count
		while true {
			reachedLimit = false
			if try isOpen(branch) {
				return true
			}
			guard reachedLimit else { return false }
			if let maximumThings, thingLimit >= maximumThings {
				return false
			}
			thingLimit += 1
		}
	}

	/// Whether this attempt can be finished without contradicting itself. Alternatives wait in a list rather than
	/// on the call stack, since a deep search would overflow it, and the stack on the main thread is small.
	private mutating func isOpen(_ start: Branch) throws -> Bool {
		var alternatives = [start]

		while var branch = alternatives.popLast() {
			attempt: while true {
				steps += 1
				guard steps < stepLimit else { throw OutOfSteps() }

				if let (node, world) = branch.agenda.popLast() {
					guard branch.apply(node, world: world) else { break attempt }
					continue
				}

				// What's already known often settles a choice, and that's far cheaper than trying both sides
				steps += branch.choices.count
				guard branch.settleChoices() else { break attempt }
				if !branch.agenda.isEmpty {
					continue
				}

				if let (left, right, world) = branch.choices.popLast() {
					steps += branch.size
					var other = branch
					other.add(right, world: world)
					// Trying the right side only matters when the left is false
					switch left {
						case .fact, .same:
							other.add(left.negated, world: world)
						default:
							break
					}
					alternatives.append(other)
					branch.add(left, world: world)
					continue
				}

				if let (letter, body, world) = branch.witnesses.popLast() {
					let things = branch.distinctThings
					steps += branch.size * (things.count + 1)

					let instances = things.map { (name: $0, known: branch.truth(of: body.replacing(letter, with: $0), world: world)) }
					if instances.contains(where: { $0.known == true }) {
						continue
					}

					// Tried last, since something that already exists might do, which keeps models small and finite
					if things.count < thingLimit {
						var other = branch
						let name = other.addThing()
						other.add(body.replacing(letter, with: name), world: world)
						alternatives.append(other)
					} else {
						reachedLimit = true
					}

					for (name, known) in instances.reversed() where known != false {
						var other = branch
						other.add(body.replacing(letter, with: name), world: world)
						alternatives.append(other)
					}
					break attempt
				}

				return true
			}
		}

		return false
	}
}

/// One attempt at building a situation. Copied whenever it has to try alternatives.
private struct Branch {
	struct Item: Hashable {
		let node: Node
		let world: Int
	}

	struct Key: Hashable {
		let fact: Fact
		let world: Int
	}

	var agenda: [(Node, Int)] = []
	var choices: [(Node, Node, Int)] = []
	var witnesses: [(Int, Node, Int)] = []
	var names: [Int] = []

	private var nextName: Int
	private var seen: Set<Item> = []
	private var universals: [(Int, Node, Int)] = []
	private var necessities: [Node] = []
	private var possibilities: Set<Node> = []
	private var worldCount = 1
	private var facts: [Key: Bool] = [:]
	private var parents: [Int: Int] = [:]
	private var differences: [(Int, Int)] = []

	init(nextName: Int) {
		self.nextName = nextName
	}

	/// Roughly what it costs to copy and carry on with
	var size: Int {
		seen.count
	}

	var distinctThings: [Int] {
		var found: Set<Int> = []
		return names.filter { found.insert(root(of: $0)).inserted }
	}

	mutating func makeName() -> Int {
		nextName += 1
		return nextName
	}

	/// A new thing has to meet every ∀ already made
	mutating func addThing() -> Int {
		let name = makeName()
		names.append(name)
		for (letter, body, world) in universals {
			add(body.replacing(letter, with: name), world: world)
		}
		return name
	}

	mutating func add(_ node: Node, world: Int) {
		if seen.insert(Item(node: node, world: world)).inserted {
			agenda.append((node, world))
		}
	}

	/// False when it contradicts what's already there
	mutating func apply(_ node: Node, world: Int) -> Bool {
		switch node {
			case .top:
				return true
			case .bottom:
				return false
			case let .fact(fact, value):
				return record(fact, value, world: world)
			case let .same(left, right, value):
				return record(left, right, same: value)
			case let .and(left, right):
				add(left, world: world)
				add(right, world: world)
				return true
			case let .or(left, right):
				choices.append((left, right, world))
				return true
			case let .always(value):
				necessities.append(value)
				for other in 0 ..< worldCount {
					add(value, world: other)
				}
				return true
			case let .sometimes(value):
				// In S5 it doesn't matter which world asked, so one witness is enough for everyone
				if possibilities.insert(value).inserted {
					let new = worldCount
					worldCount += 1
					for necessity in necessities {
						add(necessity, world: new)
					}
					add(value, world: new)
				}
				return true
			case let .all(letter, body):
				universals.append((letter, body, world))
				for name in names {
					add(body.replacing(letter, with: name), world: world)
				}
				return true
			case let .some(letter, body):
				witnesses.append((letter, body, world))
				return true
		}
	}

	/// True or false when what's known already decides it, nil when it doesn't
	func truth(of node: Node, world: Int) -> Bool? {
		switch node {
			case .top:
				return true
			case .bottom:
				return false
			case let .fact(fact, value):
				return facts[Key(fact: canonical(fact), world: world)].map { $0 == value }
			case let .same(left, right, value):
				guard case let .name(left) = left, case let .name(right) = right else { return nil }
				let (first, second) = (root(of: left), root(of: right))
				if first == second {
					return value
				}
				let isDifferent = differences.contains { pair in
					let pair = (root(of: pair.0), root(of: pair.1))
					return pair == (first, second) || pair == (second, first)
				}
				return isDifferent ? !value : nil
			case let .and(left, right):
				let (left, right) = (truth(of: left, world: world), truth(of: right, world: world))
				if left == false || right == false {
					return false
				}
				return left == true && right == true ? true : nil
			case let .or(left, right):
				let (left, right) = (truth(of: left, world: world), truth(of: right, world: world))
				if left == true || right == true {
					return true
				}
				return left == false && right == false ? false : nil
			case .always, .sometimes, .all, .some:
				return nil
		}
	}

	/// Drops the choices that are already met, and takes the only side left of those with one ruled out.
	/// False when both sides of one are ruled out.
	mutating func settleChoices() -> Bool {
		var open: [(Node, Node, Int)] = []
		for choice in choices {
			let (left, right, world) = choice
			switch (truth(of: left, world: world), truth(of: right, world: world)) {
				case (true, _), (_, true):
					break
				case (false, false):
					return false
				case (false, nil):
					add(right, world: world)
				case (nil, false):
					add(left, world: world)
				case (nil, nil):
					open.append(choice)
			}
		}
		choices = open
		return true
	}

	private func root(of name: Int) -> Int {
		var current = name
		while let parent = parents[current] {
			current = parent
		}
		return current
	}

	private func canonical(_ fact: Fact) -> Fact {
		Fact(kind: fact.kind, things: fact.things.map { thing in
			if case let .name(name) = thing {
				return .name(root(of: name))
			}
			return thing
		})
	}

	private mutating func record(_ fact: Fact, _ value: Bool, world: Int) -> Bool {
		let key = Key(fact: canonical(fact), world: world)
		if let known = facts[key] {
			return known == value
		}
		facts[key] = value
		return true
	}

	private mutating func record(_ left: Thing, _ right: Thing, same: Bool) -> Bool {
		guard case let .name(left) = left, case let .name(right) = right else { return true }
		let (first, second) = (root(of: left), root(of: right))

		guard same else {
			differences.append((first, second))
			return first != second
		}
		guard first != second else { return true }

		parents[first] = second
		guard !differences.contains(where: { root(of: $0.0) == root(of: $0.1) }) else { return false }

		// Facts about the old name are now facts about the new one, which might contradict what's known
		let old = facts
		facts = [:]
		for (key, value) in old {
			let moved = Key(fact: canonical(key.fact), world: key.world)
			if let known = facts[moved], known != value {
				return false
			}
			facts[moved] = value
		}
		return true
	}
}
