import Foundation

/// Answers app.ts's asks with MatrixCore (the core-*.swift files beside this one).
final class Matrix: ExactModule {
    override func call(_ request: [String: Any]) throws -> [String: Any] {
        switch request["op"] as? String {
        case "sdk": return ["commit": MatrixCore.sdkCommit()]
        default: throw ExactNativeRefusal("matrix answers sdk")
        }
    }
}
let exactModule: ExactModule.Type = Matrix.self
