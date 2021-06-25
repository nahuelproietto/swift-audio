// swift-tools-version:5.2
import PackageDescription

let package = Package(
    name: "swift-graph-engine",
    platforms: [
        .macOS(.v10_15), .iOS(.v11)
    ],
    products: [
        .library(name: "IO", targets: ["IO"])
    ],
    dependencies: []
)


#if os(macOS)
package.targets += [
    .target(name: "IO",
            dependencies: [
                .target(name: "CIO"),
            ]),
    .target(name: "SampleApplication",
            dependencies: [
                .target(name: "IO"),
            ]),
    .target(
        name: "CIO",
        cSettings: [
            .define("__MACOSX_CORE__"),
            .define("MINIAUDIO_IMPLEMENTATION"),
            .define("DRWAV_IMPLEMENTATION")
        ]),
]
#endif
