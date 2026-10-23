// swift-tools-version: 5.9
import PackageDescription

// Run the same persistence/learning tests on macOS when an iOS simulator's
// instrumentation service is unavailable. The app itself remains an iPad app.
let package = Package(
    name: "TrailheadCore",
    platforms: [.macOS(.v14)],
    products: [.library(name: "Trailhead", targets: ["Trailhead"])],
    targets: [
        .target(name: "Trailhead", path: "Trailhead", exclude: ["TrailheadApp.swift", "PracticeViews.swift", "ParentViews.swift", "QuizViews.swift", "Assets.xcassets"], sources: ["Models.swift", "Store.swift"]),
        .testTarget(name: "TrailheadTests", dependencies: ["Trailhead"], path: "Tests")
    ]
)
