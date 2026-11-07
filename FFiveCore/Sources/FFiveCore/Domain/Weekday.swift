import Foundation

/// The day of the week a block day is trained on. It labels the day; the plan never reads it.
public enum Weekday: String, CaseIterable, Identifiable, Codable {
    case monday, tuesday, wednesday, thursday, friday, saturday, sunday

    public var id: String { rawValue }
    public var name: String { rawValue.capitalized }
    public var shortName: String { String(name.prefix(3)) }
}

/// How far a weekday label change reaches.
public enum WeekdayScope {
    case thisSession
    case everyWeek
}
