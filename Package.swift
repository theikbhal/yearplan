// swift-tools-version:5.9
import PackageDescription
let package = Package(
    name: "YearPlan",
    platforms: [.macOS(.v13)],
    targets: [.executableTarget(name: "YearPlan", path: "Sources/YearPlan")]
)
