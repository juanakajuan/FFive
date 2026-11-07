import XCTest

@testable import FFiveCore

final class WeekdayScheduleTests: XCTestCase {
    func testFourDaysFromMondayTrainMondayTuesdayThursdayFriday() {
        XCTAssertEqual(Weekday.suggested(days: 4, startingOn: .monday), [.monday, .tuesday, .thursday, .friday])
    }

    func testEachCountFromMondayMatchesItsSpread() {
        let expected: [Int: [Weekday]] = [
            2: [.monday, .thursday],
            3: [.monday, .wednesday, .friday],
            4: [.monday, .tuesday, .thursday, .friday],
            5: [.monday, .tuesday, .thursday, .friday, .saturday],
            6: [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday],
        ]
        for (count, days) in expected {
            XCTAssertEqual(Weekday.suggested(days: count, startingOn: .monday), days, "\(count) days")
        }
    }

    func testAnyStartShiftsTheMondaySchedule() {
        for count in 2...6 {
            let monday = Weekday.suggested(days: count, startingOn: .monday)
            for (shift, start) in Weekday.allCases.enumerated() {
                let schedule = Weekday.suggested(days: count, startingOn: start)
                XCTAssertEqual(schedule.first, start, "\(count) days from \(start)")
                XCTAssertEqual(schedule, monday.map { $0?.advanced(by: shift) }, "\(count) days from \(start)")
            }
        }
    }

    func testRestDaysBreakUpTrainingEvenly() {
        for count in 2...6 {
            for start in Weekday.allCases {
                let schedule = Weekday.suggested(days: count, startingOn: start).compactMap { $0 }
                XCTAssertEqual(Set(schedule).count, count, "no weekday twice")
                let rests = 7 - count
                let longestAllowed = (count + rests - 1) / rests
                XCTAssertLessThanOrEqual(
                    longestRun(of: Set(schedule)), longestAllowed, "\(count) days from \(start): \(schedule)")
            }
        }
    }

    func testDaysPastTheWeekGetNoWeekday() {
        XCTAssertEqual(Weekday.suggested(days: 7, startingOn: .sunday), Weekday.allCases.map { $0.advanced(by: 6) })
        XCTAssertEqual(Weekday.suggested(days: 9, startingOn: .monday).suffix(2), [nil, nil])
        XCTAssertEqual(Weekday.suggested(days: 0, startingOn: .monday), [])
    }

    func testAdvancedWrapsBothWays() {
        XCTAssertEqual(Weekday.sunday.advanced(by: 1), .monday)
        XCTAssertEqual(Weekday.monday.advanced(by: -1), .sunday)
        XCTAssertEqual(Weekday.wednesday.advanced(by: 14), .wednesday)
    }

    func testChoosingAStartLabelsEveryDraftDay() {
        var draft = MesoDraft(template: nil)
        draft.days = (1...4).map { MesoDraft.Day(name: "Day \($0)", slots: []) }
        draft.schedule(startingOn: .wednesday)
        XCTAssertEqual(draft.startWeekday, .wednesday)
        XCTAssertEqual(draft.days.map(\.weekday), [.wednesday, .thursday, .saturday, .sunday])

        draft.days[2].weekday = .friday
        XCTAssertEqual(draft.days.map(\.weekday), [.wednesday, .thursday, .friday, .sunday], "a day can be changed")
    }

    /// The longest stretch of consecutive training weekdays, wrapping Sunday into Monday.
    private func longestRun(of training: Set<Weekday>) -> Int {
        let week = Weekday.allCases.map(training.contains)
        var longest = 0
        var run = 0
        for trains in week + week {
            run = trains ? run + 1 : 0
            longest = max(longest, min(run, 7))
        }
        return longest
    }
}
