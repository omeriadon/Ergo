// swift-tools-version: 6.2

import PackageDescription

/// Sends the corpus through a running Ergo server, exactly as the app does, and scores the translations by meaning
let package = Package(
	name: "Evals",
	platforms: [
		.macOS("27.0"),
	],
	dependencies: [
		.package(path: "../ErgoKit"),
	],
	targets: [
		.executableTarget(
			name: "ErgoEval",
			dependencies: [
				.product(name: "ErgoLogic", package: "ErgoKit"),
				.product(name: "ErgoTranslation", package: "ErgoKit"),
				.product(name: "ErgoProtocol", package: "ErgoKit"),
				.product(name: "ErgoClient", package: "ErgoKit"),
			]
		),
		.testTarget(
			name: "EvalCorpusTests",
			dependencies: [
				"ErgoEval",
				.product(name: "ErgoLogic", package: "ErgoKit"),
				.product(name: "ErgoTranslation", package: "ErgoKit"),
			]
		),
	],
	swiftLanguageModes: [.v6]
)
