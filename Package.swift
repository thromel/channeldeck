// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ChannelDeck",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "ChannelDeck", targets: ["ChannelDeck"])
    ],
    targets: [
        .executableTarget(
            name: "ChannelDeck",
            path: "Sources/ChannelDeck",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("AVKit"),
                .linkedFramework("Security")
            ]
        ),
        .testTarget(
            name: "ChannelDeckTests",
            dependencies: ["ChannelDeck"],
            path: "Tests/ChannelDeckTests"
        )
    ]
)
