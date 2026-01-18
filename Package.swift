// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "swift-task-store",
  platforms: [
    .iOS(.v17),
    .macOS(.v14),
    .tvOS(.v17),
    .watchOS(.v10),
    .visionOS(.v1),
  ],
  products: [
    .library(
      name: "TaskStore",
      targets: ["TaskStore"]
    ),
  ],
  targets: [
    .target(
      name: "TaskStore",
      swiftSettings: [.swiftLanguageMode(.v6)]
    ),
    .testTarget(
      name: "TaskStoreTests",
      dependencies: ["TaskStore"],
      swiftSettings: [.swiftLanguageMode(.v6)]
    ),
  ]
)
