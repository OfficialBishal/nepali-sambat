// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "NepaliPatro",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PatroCore", targets: ["PatroCore"]),
        .executable(name: "NepaliPatro", targets: ["NepaliPatro"]),
        .executable(name: "NepaliPatroWidgets", targets: ["NepaliPatroWidgets"]),
        .executable(name: "patro", targets: ["patro"]),
    ],
    targets: [
        .target(name: "PatroCore"),
        .target(name: "PatroUI", dependencies: ["PatroCore"]),
        .executableTarget(
            name: "NepaliPatro",
            dependencies: ["PatroCore", "PatroUI"]
        ),
        .executableTarget(
            name: "NepaliPatroWidgets",
            dependencies: ["PatroCore", "PatroUI"],
            swiftSettings: [.unsafeFlags(["-application-extension"])],
            linkerSettings: [.unsafeFlags(["-Xlinker", "-application_extension"])]
        ),
        .executableTarget(name: "patro", dependencies: ["PatroCore"]),
        .executableTarget(name: "PatroChecks", dependencies: ["PatroCore"]),
    ],
    swiftLanguageModes: [.v5]
)
