// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MatrixRustSDK",
    platforms: [.iOS(.v16), .macOS(.v14)],
    products: [.library(name: "MatrixRustSDK", targets: ["MatrixRustSDK"])],
    targets: [
        .binaryTarget(name: "MatrixSDKFFI", path: "MatrixSDKFFI.xcframework"),
        .target(name: "MatrixRustSDK", dependencies: ["MatrixSDKFFI"]),
    ]
)
