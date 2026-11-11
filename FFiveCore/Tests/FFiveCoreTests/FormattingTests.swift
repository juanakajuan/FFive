import Foundation
import XCTest

@testable import FFiveCore

final class FormattingTests: XCTestCase {
    func testSessionDayShowsWeekdayMonthDayAndYear() {
        let utc = TimeZone(identifier: "UTC")!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        let date = calendar.date(from: DateComponents(year: 2026, month: 10, day: 31, hour: 12))!
        var style = Date.FormatStyle.sessionDay.locale(Locale(identifier: "en_US"))
        style.timeZone = utc
        XCTAssertEqual(date.formatted(style), "Sat, Oct 31, 2026")
    }
}
