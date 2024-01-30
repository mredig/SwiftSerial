// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "SwiftSerial",
	platforms: [
		.macOS(.v10_15),
	],
	products: [
		.library(name: "SwiftSerial", targets: ["SwiftSerial"]),
		.executable(name: "SerialTerminal", targets: ["SerialTerminal"])
	],
	dependencies: [
		.package(url: "https://github.com/apple/swift-argument-parser.git", .upToNextMinor(from: "1.3.0")),
	],
	targets: [
		.target(
			name: "SwiftSerial",
			dependencies: []
		),
		.executableTarget(
			name: "SerialTerminal",
			dependencies: [
				"SwiftSerial",
				.product(name: "ArgumentParser", package: "swift-argument-parser"),
			]
		)
	]
)
