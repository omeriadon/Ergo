// swift-tools-version: 6.2

import PackageDescription

/// What the app, the server and the evals share: the logic checker, the translation contract,
/// the sync merge rules, the wire protocol and a client for it
let package = Package(
	name: "ErgoKit",
	platforms: [
		.iOS("27.0"),
		.macOS("27.0"),
	],
	products: [
		.library(name: "ErgoLogic", targets: ["ErgoLogic"]),
		.library(name: "ErgoTranslation", targets: ["ErgoTranslation"]),
		.library(name: "ErgoSync", targets: ["ErgoSync"]),
		.library(name: "ErgoProtocol", targets: ["ErgoProtocol"]),
		.library(name: "ErgoClient", targets: ["ErgoClient"]),
	],
	targets: [
		.target(name: "ErgoLogic"),
		.target(name: "ErgoTranslation", dependencies: ["ErgoLogic"]),
		.target(name: "ErgoSync"),
		.target(name: "ErgoProtocol", dependencies: ["ErgoTranslation", "ErgoSync"]),
		.target(name: "ErgoClient", dependencies: ["ErgoProtocol"]),

		.testTarget(name: "ErgoLogicTests", dependencies: ["ErgoLogic"]),
		.testTarget(name: "ErgoTranslationTests", dependencies: ["ErgoLogic", "ErgoTranslation"]),
		.testTarget(name: "ErgoSyncTests", dependencies: ["ErgoSync"]),
		.testTarget(name: "ErgoProtocolTests", dependencies: ["ErgoLogic", "ErgoTranslation", "ErgoSync", "ErgoProtocol"]),
		.testTarget(name: "ErgoClientTests", dependencies: ["ErgoSync", "ErgoProtocol", "ErgoClient"]),
	],
	swiftLanguageModes: [.v6]
)
