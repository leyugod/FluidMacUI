// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "FluidMacUI",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .library(
            name: "FluidMacUI",
            targets: ["FluidMacUI"]
        ),
        .executable(
            name: "FluidMacShowcase",
            targets: ["FluidMacShowcase"]
        )
    ],
    targets: [
        .target(
            name: "FluidMacUI",
            path: "Sources/FluidMacUI",
            swiftSettings: [
                .defaultIsolation(MainActor.self)
            ]
        ),
        .executableTarget(
            name: "FluidMacShowcase",
            dependencies: ["FluidMacUI"],
            path: "Examples/FluidMacShowcase",
            swiftSettings: [
                .defaultIsolation(MainActor.self)
            ]
        ),
        .testTarget(
            name: "FluidMacUITests",
            dependencies: ["FluidMacUI"],
            path: "Tests/FluidMacUITests",
            swiftSettings: [
                .defaultIsolation(MainActor.self)
            ]
        )
    ]
)
