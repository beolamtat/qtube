import XCTest
@testable import QTube

final class UpdateCheckerTests: XCTestCase {
    func testVersionComparisonIdentifiesNewerVersions() {
        XCTAssertTrue(UpdateChecker.isVersion("1.0.2", newerThan: "1.0.1"))
        XCTAssertTrue(UpdateChecker.isVersion("1.1.0", newerThan: "1.0.1"))
        XCTAssertTrue(UpdateChecker.isVersion("2.0.0", newerThan: "1.9.9"))
        XCTAssertTrue(UpdateChecker.isVersion("1.0.10", newerThan: "1.0.2"))
        XCTAssertTrue(UpdateChecker.isVersion("1.0.1.1", newerThan: "1.0.1"))
    }

    func testVersionComparisonRejectsOlderOrEqualVersions() {
        XCTAssertFalse(UpdateChecker.isVersion("1.0.1", newerThan: "1.0.1"))
        XCTAssertFalse(UpdateChecker.isVersion("1.0.0", newerThan: "1.0.1"))
        XCTAssertFalse(UpdateChecker.isVersion("0.9.9", newerThan: "1.0.1"))
        XCTAssertFalse(UpdateChecker.isVersion("1.0.1", newerThan: "1.0.2"))
    }
}
