// swift-tools-version:5.9
import PackageDescription

// mx: the chat app's command line, for agents. it links the same MatrixCore as the app
// (Sources/MatrixCore is a link to matrix-core's sources) and a macOS build of the sdk
// that scripts/setup-cli-sdk.sh writes into .sdk. only MatrixCore calls the sdk.
let package = Package(
    name: "mx",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "mx", targets: ["mx"]),
    ],
    targets: [
        .binaryTarget(name: "MatrixSDKFFI", path: ".sdk/MatrixSDKFFI.xcframework"),
        .target(name: "MatrixRustSDK", dependencies: ["MatrixSDKFFI"], path: ".sdk/MatrixRustSDK"),
        .target(name: "MatrixCore", dependencies: ["MatrixRustSDK"]),
        .target(name: "CLIKit"),
        .executableTarget(name: "mx", dependencies: ["MatrixCore", "CLIKit"]),
        .testTarget(name: "CLIKitTests", dependencies: ["CLIKit"]),
    ]
)
