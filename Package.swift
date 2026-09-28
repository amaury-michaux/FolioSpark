// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "FolioSpark",
    platforms: [.macOS(.v26)],
    targets: [.executableTarget(name: "Reader", swiftSettings: [.swiftLanguageMode(.v5)])]
)
