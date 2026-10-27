import Foundation
// a swift package build imports the sdk as a module; the exact app compiles
// these files into the same module as the sdk's bindings, so there is nothing to import.
#if canImport(MatrixRustSDK)
import MatrixRustSDK
#endif

/// The only code that calls matrix-rust-sdk. Its public API uses plain types,
/// so the app (Exact today, Expo as the fallback) never sees an sdk type.
public enum MatrixCore {
    /// The matrix-rust-sdk commit the linked library was built from.
    public static func sdkCommit() -> String {
        sdkGitSha()
    }
}
