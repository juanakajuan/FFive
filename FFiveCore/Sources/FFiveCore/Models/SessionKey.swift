import Foundation

public struct SessionKey: Hashable, Comparable, Codable {
    public let week: Int
    public let dayIndex: Int

    public init(week: Int, dayIndex: Int) {
        self.week = week
        self.dayIndex = dayIndex
    }

    public static func < (lhs: SessionKey, rhs: SessionKey) -> Bool {
        (lhs.week, lhs.dayIndex) < (rhs.week, rhs.dayIndex)
    }
}
