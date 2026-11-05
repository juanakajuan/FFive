import XCTest

@testable import FFiveCore

final class A11yTests: XCTestCase {
    func testSlugCollapsesSeparators() {
        XCTAssertEqual(A11y.slug("Full Body, 3 Days"), "full-body-3-days")
        XCTAssertEqual(A11y.slug("Upper/Lower, 4 Days"), "upper-lower-4-days")
        XCTAssertEqual(A11y.slug("Lateral Raise"), "lateral-raise")
        XCTAssertEqual(A11y.slug("Pretty good"), "pretty-good")
        XCTAssertEqual(A11y.slug("W1"), "w1")
        XCTAssertEqual(A11y.slug("Healed just in time"), "healed-just-in-time")
        XCTAssertEqual(A11y.slug("  --Hi!  "), "hi")
    }

    func testIdentifierForms() {
        XCTAssertEqual(A11y.setWeight.indexed(3), "set.weight.3")
        XCTAssertEqual(A11y.pickerRow.keyed("Lateral Raise"), "picker.row.lateral-raise")
        XCTAssertEqual(A11y.workoutMenu.rawValue, "workout.menu")
    }

    func testRawValuesAreUnique() {
        let raws = A11y.allCases.map(\.rawValue)
        XCTAssertEqual(Set(raws).count, raws.count)
    }

    func testNoPlainCaseIsAPrefixOfAnother() {
        let plain = A11y.allCases.filter { !A11y.indexed.contains($0) && !A11y.keyed.contains($0) }
        for a in plain {
            for b in A11y.allCases where a != b {
                XCTAssertFalse(b.rawValue.hasPrefix(a.rawValue + "."), "\(a.rawValue) is a prefix of \(b.rawValue)")
            }
        }
    }
}
