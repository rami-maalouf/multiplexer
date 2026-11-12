// swift-tools-version:5.9
import PackageDescription
import Foundation

// opt in through scripts/test-matrix-core-macos.sh; the release dependency stays
// the default for ios, regardless of which host evaluates this manifest.
let macTests = ProcessInfo.processInfo.environment["MATRIX_CORE_MACOS"] == "1"
let sdk: Package.Dependency = macTests
    ? .package(path: ".build/macos-sdk")
    : .package(url: "https://github.com/element-hq/matrix-rust-components-swift", exact: "26.10.27")
let sdkIdentity = macTests ? "macos-sdk" : "matrix-rust-components-swift"

// the same files also compile inside the exact app, which gets the sdk from
// scripts/setup-matrix-sdk.sh; keep this version equal to the script's.
let package = Package(
    name: "MatrixCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "MatrixCore", targets: ["MatrixCore"]),
    ],
    dependencies: [
        sdk,
    ],
    targets: [
        .target(name: "MatrixCore", dependencies: [.product(name: "MatrixRustSDK", package: sdkIdentity)]),
        macTests
            ? .testTarget(name: "MatrixCoreMacTests", dependencies: ["MatrixCore"])
            : .testTarget(name: "MatrixCoreTests", dependencies: ["MatrixCore"]),
    ]
)
