// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "AirPodsSoundQualityFixerPackage",
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
    .target(name: "AudioInputFixer", swiftSettings: approachableConcurrency),
    .testTarget(
      name: "AudioInputFixerTests",
      dependencies: [
        "AudioInputFixer",
        .product(name: "CustomDump", package: "swift-custom-dump"),
      ],
      swiftSettings: approachableConcurrency
    ),
  ]
)

// Matches the app target's SWIFT_APPROACHABLE_CONCURRENCY, whose remaining features Swift 6 enables
// by default, so code behaves the same on either side of the module boundary.
let approachableConcurrency: [SwiftSetting] = [
  .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
  .enableUpcomingFeature("InferIsolatedConformances"),
]
