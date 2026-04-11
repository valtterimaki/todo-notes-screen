// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TodoNotesScreen",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "TodoNotesScreen",
            path: "Sources/TodoNotesScreen"
        )
    ]
)
