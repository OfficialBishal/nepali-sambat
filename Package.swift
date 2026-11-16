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
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-application_extension"]),
                // App extensions start in Foundation's NSExtensionMain, which sets the extension up and
                // then calls `main`; Xcode adds this for widget targets. Without it the widget crashed at
                // launch and never appeared in the widget gallery. Debug builds keep the normal entry so
                // `SambatWidgets --render` still works.
                .unsafeFlags(["-Xlinker", "-e", "-Xlinker", "_NSExtensionMain"], .when(configuration: .release)),
            ]
        ),
        .executableTarget(name: "SambatCLI", dependencies: ["SambatCore"]),
        .executableTarget(name: "SambatChecks", dependencies: ["SambatCore"]),
    ],
    swiftLanguageModes: [.v5]
)
