import MatrixCore
import XCTest

final class SDKLinkTests: XCTestCase {
    func testTheNativeLibraryMatchesThePinnedSDK() {
        XCTAssertEqual(MatrixCore.sdkCommit(), "14a0ada4fc")
    }
}
