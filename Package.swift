// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Sambat",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "SambatCore", targets: ["SambatCore"]),
        .executable(name: "SambatApp", targets: ["SambatApp"]),
        .executable(name: "SambatWidgets", targets: ["SambatWidgets"]),
        .executable(name: "sambat", targets: ["SambatCLI"]),
    ],
    targets: [
        .target(name: "SambatCore"),
        .target(name: "SambatUI", dependencies: ["SambatCore"]),
        .executableTarget(
            name: "SambatApp",
            dependencies: ["SambatCore", "SambatUI"]
        ),
        .executableTarget(
            name: "SambatWidgets",
            dependencies: ["SambatCore", "SambatUI"],
            swiftSettings: [.unsafeFlags(["-application-extension"])],
            linkerSettings: [.unsafeFlags(["-Xlinker", "-application_extension"])]
        ),
        .executableTarget(name: "SambatCLI", dependencies: ["SambatCore"]),
        .executableTarget(name: "SambatChecks", dependencies: ["SambatCore"]),
    ],
    swiftLanguageModes: [.v5]
)
