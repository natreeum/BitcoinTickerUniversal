// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "BitcoinTickerUniversal",
    platforms: [.macOS(.v11)],
    products: [
        .executable(name: "BitcoinTickerUniversal", targets: ["BitcoinTickerUniversal"]),
        .executable(name: "BitcoinTickerUninstaller", targets: ["BitcoinTickerUninstaller"])
    ],
    targets: [
        .executableTarget(
            name: "BitcoinTickerUniversal",
            path: "Sources/BitcoinTickerUniversal"
        ),
        .executableTarget(
            name: "BitcoinTickerUninstaller",
            path: "Sources/BitcoinTickerUninstaller"
        )
    ]
)
