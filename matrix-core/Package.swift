// swift-tools-version:5.9
import PackageDescription

// the same files also compile inside the exact app, which gets the sdk from
// scripts/setup-matrix-sdk.sh; keep this version equal to the script's.
let package = Package(
    name: "MatrixCore",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "MatrixCore", targets: ["MatrixCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/element-hq/matrix-rust-components-swift", exact: "26.10.27"),
    ],
    targets: [
        .target(name: "MatrixCore", dependencies: [.product(name: "MatrixRustSDK", package: "matrix-rust-components-swift")]),
        .testTarget(name: "MatrixCoreTests", dependencies: ["MatrixCore"]),
    ]
)
