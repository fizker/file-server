// swift-tools-version:5.10
import PackageDescription

let package = Package(
	name: "file-server",
	platforms: [
		.macOS(.v12),
	],
	dependencies: [
		// 💧 A server-side Swift web framework.
		.package(url: "https://github.com/vapor/vapor.git", from: "4.54.0"),
		.package(url: "https://github.com/fizker/swift-environment-variables.git", from: "1.0.0"),
		.package(url: "https://github.com/apple/swift-collections.git", from: "1.0.2"),
	],
	targets: [
		.target(
			name: "App",
			dependencies: [
				.product(name: "Vapor", package: "vapor"),
				.product(name: "EnvironmentVariables", package: "swift-environment-variables"),
				.product(name: "Collections", package: "swift-collections"),
			],
			swiftSettings: [
				// Enable better optimizations when building in Release configuration. Despite the use of
				// the `.unsafeFlags` construct required by SwiftPM, this flag is recommended for Release
				// builds. See <https://github.com/swift-server/guides#building-for-production> for details.
				.unsafeFlags(["-cross-module-optimization"], .when(configuration: .release)),
			]
		),
		.executableTarget(name: "Run", dependencies: [.target(name: "App")]),
		.testTarget(name: "AppTests", dependencies: [
			.target(name: "App"),
			.product(name: "XCTVapor", package: "vapor"),
		])
	]
)
