// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ChannelDeck",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .executable(name: "ChannelDeck", targets: ["ChannelDeck"]),
        .executable(name: "ChannelDeckIOS", targets: ["ChannelDeckIOS"])
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
        .executableTarget(
            name: "ChannelDeckIOS",
            path: "Sources/ChannelDeckIOS",
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("AVKit"),
                .linkedFramework("Security")
            ]
        ),
        .testTarget(
            name: "ChannelDeckTests",
            dependencies: ["ChannelDeck", "ChannelDeckIOS"],
            path: "Tests/ChannelDeckTests"
        )
    ]
)
