// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "HistorySpike",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/ejbills/mediaremote-adapter", revision: "cf30c4f1af29b5829d859f088f8dbdf12611a046")
    ],
    targets: [
        .executableTarget(
            name: "HistorySpike",
            dependencies: [
                .product(name: "MediaRemoteAdapter", package: "mediaremote-adapter")
            ]
        )
    ]
)
