import Foundation
import XCTest

@testable import FFiveCore

final class CloudKitFieldsTests: XCTestCase {
    private let file = URL(filePath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().appending(path: "cloudkit/schema-fields.txt")

    func testCheckedInFieldsMatchTheModels() throws {
        let expected = CloudKitSchema.fields.joined(separator: "\n") + "\n"
        if ProcessInfo.processInfo.environment["UPDATE_CLOUDKIT_FIELDS"] == "1" {
            try expected.write(to: file, atomically: true, encoding: .utf8)
        }
        let checkedIn = try String(contentsOf: file, encoding: .utf8)
        XCTAssertEqual(
            checkedIn, expected,
            """
            The models changed the CloudKit schema. Run `UPDATE_CLOUDKIT_FIELDS=1 swift test --package-path FFiveCore \
            --filter CloudKitFieldsTests` and commit cloudkit/schema-fields.txt. Before the next TestFlight upload, \
            deploy the new fields to Production in the CloudKit Console; scripts/cloudkit-schema.sh checks it.
            """)
    }
}
