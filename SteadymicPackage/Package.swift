// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "SteadymicPackage",
  platforms: [
    .macOS(.v14),
  ],
  products: [
    .library(name: "AudioInputFixer", targets: ["AudioInputFixer"]),
  ],
  dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-custom-dump", from: "1.0.0"),
  ],
  targets: [
    .target(name: "AudioInputFixer", swiftSettings: appConcurrencySettings),
    .testTarget(
      name: "AudioInputFixerTests",
      dependencies: [
        "AudioInputFixer",
        .product(name: "CustomDump", package: "swift-custom-dump"),
      ],
      swiftSettings: appConcurrencySettings
    ),
  ]
)

// Matches the app target's SWIFT_DEFAULT_ACTOR_ISOLATION and SWIFT_APPROACHABLE_CONCURRENCY, whose
// remaining features Swift 6 enables by default, so code behaves the same on either side of the
// module boundary.
let appConcurrencySettings: [SwiftSetting] = [
  .defaultIsolation(MainActor.self),
  .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
  .enableUpcomingFeature("InferIsolatedConformances"),
]
