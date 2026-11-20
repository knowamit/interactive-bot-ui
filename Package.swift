// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "BotUI",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [.library(name: "BotUI", targets: ["BotUI"])],
    targets: [
        .target(name: "BotUI"),
        .testTarget(name: "BotUITests", dependencies: ["BotUI"]),
    ]
)
