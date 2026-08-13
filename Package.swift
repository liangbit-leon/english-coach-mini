// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "EnglishCoachMini",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "EnglishCoachMini", targets: ["EnglishCoachMini"])
    ],
    targets: [
        .executableTarget(name: "EnglishCoachMini")
    ]
)
