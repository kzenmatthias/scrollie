// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Scrollie",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Scrollie",
            path: "Scrollie",
            exclude: ["Info.plist"]
        )
    ]
)
