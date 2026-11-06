//
//  CanvasLayoutTests.swift
//  ErgoKit
//
//  Created by Adon Omeri on 6/11/2026.
//

import ErgoLogic
import Foundation
import Testing

/// Layered layout and finding free space for one more box
struct CanvasLayoutTests {
	let id = ArgumentFixtures.id

	func rects(_ map: TestMap) -> [CanvasRect] {
		map.statements.map { CanvasRect(center: $0.position, size: CanvasLayout.boxSize) }
	}

	func noOverlaps(_ map: TestMap, margin: Double = 0, sourceLocation: SourceLocation = #_sourceLocation) {
		let boxes = rects(map)
		for (index, box) in boxes.enumerated() {
			for other in boxes[(index + 1)...] {
				#expect(!box.intersects(other, margin: margin), sourceLocation: sourceLocation)
			}
		}
	}

	/// A deterministic spread of edges that only point forwards, so it is always acyclic
	func randomMap(count: Int, seed: UInt64) -> TestMap {
		var state = seed
		func next(_ bound: Int) -> Int {
			state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
			return Int((state >> 33) % UInt64(bound))
		}

		var links: [(Int, Int)] = []
		for conclusion in 2 ... count {
			for _ in 0 ..< 1 + next(3) {
				let premise = 1 + next(conclusion - 1)
				if !links.contains(where: { $0 == (premise, conclusion) }) {
					links.append((premise, conclusion))
				}
			}
		}
		return ArgumentFixtures.map(count, links: links)
	}

	@Test func emptyAndSingle() {
		#expect(CanvasLayout.positions(for: TestMap()).isEmpty)
		let single = CanvasLayout.arranged(ArgumentFixtures.map(1))
		#expect(single.statements[0].position == CanvasPoint(x: CanvasLayout.boxSize.width / 2, y: CanvasLayout.boxSize.height / 2))
	}

	@Test func premisesAreLeftOfTheirConclusion() throws {
		let map = CanvasLayout.arranged(ArgumentFixtures.map(5, links: [(1, 3), (2, 3), (3, 4), (1, 5)]))
		for link in map.links {
			let premise = try #require(map.statement(link.premise)?.position)
			let conclusion = try #require(map.statement(link.conclusion)?.position)
			#expect(premise.x < conclusion.x)
		}
	}

	@Test func layersAreTheLongestPathFromARoot() {
		// 1 → 2 → 3, and 1 → 3 directly: 3 is still two layers across
		let map = CanvasLayout.arranged(ArgumentFixtures.map(3, links: [(1, 2), (2, 3), (1, 3)]))
		let x = map.statements.map(\.position.x)
		#expect(x[1] - x[0] == CanvasLayout.columnPitch)
		#expect(x[2] - x[1] == CanvasLayout.columnPitch)
	}

	@Test func aConclusionSitsBetweenItsPremises() {
		let map = CanvasLayout.arranged(ArgumentFixtures.map(3, links: [(1, 3), (2, 3)]))
		let y = map.statements.map(\.position.y)
		#expect(y[2] == (y[0] + y[1]) / 2)
	}

	@Test func diamondHasNoOverlap() {
		let map = CanvasLayout.arranged(ArgumentFixtures.map(4, links: [(1, 2), (1, 3), (2, 4), (3, 4)]))
		noOverlaps(map, margin: CanvasLayout.minimumGap)
		let pitch = CanvasLayout.columnPitch
		let first = CanvasLayout.boxSize.width / 2
		let expected: [Double] = [first, first + pitch, first + pitch, first + 2 * pitch]
		#expect(map.statements.map(\.position.x).sorted() == expected)
	}

	@Test func unlinkedStatementsStackInTheFirstColumn() {
		let map = CanvasLayout.arranged(ArgumentFixtures.map(4))
		#expect(Set(map.statements.map(\.position.x)).count == 1)
		#expect(Set(map.statements.map(\.position.y)).count == 4)
		noOverlaps(map)
	}

	@Test func noOverlapUpToSixtyNodes() throws {
		for seed in 1 ... 20 as ClosedRange<UInt64> {
			for count in [2, 10, 30, 60] {
				let map = CanvasLayout.arranged(randomMap(count: count, seed: seed))
				noOverlaps(map, margin: CanvasLayout.minimumGap)
				#expect(map.statements.allSatisfy { $0.position.x >= CanvasLayout.boxSize.width / 2 && $0.position.y >= CanvasLayout.boxSize.height / 2 })
				for link in map.links {
					#expect(try #require(map.statement(link.premise)?.position.x) < #require(map.statement(link.conclusion)?.position.x))
				}
			}
		}
	}

	@Test func sixtyUnlinkedAndSixtyInAChain() {
		noOverlaps(CanvasLayout.arranged(ArgumentFixtures.map(60)))
		noOverlaps(CanvasLayout.arranged(ArgumentFixtures.map(60, links: (1 ..< 60).map { ($0, $0 + 1) })))
		let wide = CanvasLayout.arranged(ArgumentFixtures.map(60, links: (1 ..< 60).map { ($0, 60) }))
		noOverlaps(wide, margin: CanvasLayout.minimumGap)
	}

	@Test func layoutIsDeterministicAndIgnoresCurrentPositions() {
		let map = randomMap(count: 40, seed: 7)
		let first = CanvasLayout.arranged(map)
		#expect(CanvasLayout.arranged(map) == first)

		var shuffled = map
		for index in shuffled.statements.indices {
			shuffled.statements[index].position = CanvasPoint(x: Double(index * 37 % 11), y: Double(index * 13 % 7))
		}
		#expect(CanvasLayout.arranged(shuffled) == first, "Dragging boxes around doesn't change what auto layout gives")
		#expect(CanvasLayout.arranged(first) == first, "Laying out twice is the same as once")
	}

	@Test func layoutOnlyMovesBoxes() {
		let map = randomMap(count: 12, seed: 3)
		let arranged = CanvasLayout.arranged(map)
		#expect(arranged.links == map.links)
		#expect(arranged.statements.map(\.id) == map.statements.map(\.id))
	}

	@Test func cyclesStillGetALayout() {
		let map = CanvasLayout.arranged(ArgumentFixtures.map(4, links: [(1, 2), (2, 3), (3, 2), (3, 4)]))
		noOverlaps(map)
		#expect(map.statements.count == 4)
	}

	// MARK: - place

	@Test func placesPremisesLeftAtTheSameHeight() {
		let map = TestMap(statements: [ArgumentFixtures.statement(1, x: 1000, y: 200)])
		let spot = CanvasLayout.place(newNodeNear: id(1), in: map)
		#expect(spot == CanvasPoint(x: 1000 - CanvasLayout.columnPitch, y: 200))
		#expect(CanvasLayout.place(newNodeNear: id(1), in: map, side: .right) == CanvasPoint(x: 1000 + CanvasLayout.columnPitch, y: 200))
		#expect(CanvasLayout.place(newNodeNear: id(1), in: map, side: .below) == CanvasPoint(x: 1000, y: 200 + CanvasLayout.rowPitch))
	}

	@Test func placeSkipsTakenSpots() {
		var map = TestMap(statements: [ArgumentFixtures.statement(1, x: 1000, y: 200)])
		var spots: [CanvasPoint] = []

		for number in 2 ... 30 {
			let spot = CanvasLayout.place(newNodeNear: id(1), in: map)
			spots.append(spot)
			map.statements.append(ArgumentFixtures.statement(number, x: spot.x, y: spot.y))
			noOverlaps(map, margin: CanvasLayout.minimumGap)
		}
		#expect(spots.first == CanvasPoint(x: 1000 - CanvasLayout.columnPitch, y: 200))
		#expect(spots[1].x == spots[0].x, "Fills the column next to it before moving out")
		#expect(spots.allSatisfy { $0.x < 1000 })
	}

	@Test func placeWorksNextToLaidOutBoxes() {
		let map = CanvasLayout.arranged(ArgumentFixtures.map(3, links: [(1, 3), (2, 3)]))
		let spot = CanvasLayout.place(newNodeNear: id(3), in: map)
		var more = map
		more.statements.append(ArgumentFixtures.statement(4, x: spot.x, y: spot.y))
		noOverlaps(more, margin: CanvasLayout.minimumGap)
	}

	@Test func placeIsDeterministic() {
		let map = randomMap(count: 20, seed: 11)
		let laidOut = CanvasLayout.arranged(map)
		#expect(CanvasLayout.place(newNodeNear: id(5), in: laidOut) == CanvasLayout.place(newNodeNear: id(5), in: laidOut))
	}

	@Test func placeFallsBackWhenTheStatementIsMissing() {
		let spot = CanvasLayout.place(newNodeNear: id(9), in: TestMap())
		#expect(spot == CanvasPoint(x: -CanvasLayout.columnPitch, y: 0))
	}

	@Test func placeWorksInACrowd() {
		let map = CanvasLayout.arranged(ArgumentFixtures.map(60))
		let spot = CanvasLayout.place(newNodeNear: id(1), in: map)
		var more = map
		more.statements.append(ArgumentFixtures.statement(61, x: spot.x, y: spot.y))
		noOverlaps(more, margin: CanvasLayout.minimumGap)
	}
}
