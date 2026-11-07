import Foundation

/// The day of the week a block day is trained on. It labels the day; the plan never reads it.
public enum Weekday: String, CaseIterable, Identifiable, Codable {
    case monday, tuesday, wednesday, thursday, friday, saturday, sunday

    public var id: String { rawValue }
    public var name: String { rawValue.capitalized }
    public var shortName: String { String(name.prefix(3)) }

    /// The weekday `days` after this one, wrapping into the next week.
    func advanced(by days: Int) -> Weekday {
        let all = Weekday.allCases
        let index = all.firstIndex(of: self)!
        return all[(index + days % all.count + all.count) % all.count]
    }

    /// A weekday for each of `count` training days, the first on `start`, with rest days spread through the week.
    /// Four days from Monday train Mon, Tue, Thu and Fri. A day past the seventh gets no weekday.
    public static func suggested(days count: Int, startingOn start: Weekday) -> [Weekday?] {
        let offsets: [Int] =
            switch count {
            case ...0: []
            case 1: [0]
            case 2: [0, 3]
            case 3: [0, 2, 4]
            case 4: [0, 1, 3, 4]
            case 5: [0, 1, 3, 4, 5]
            case 6: [0, 1, 2, 3, 4, 5]
            default: Array(0..<7)
            }
        return (0..<max(count, 0)).map { $0 < offsets.count ? start.advanced(by: offsets[$0]) : nil }
    }
}

/// How far a weekday label change reaches.
public enum WeekdayScope {
    case thisSession
    case everyWeek
}
