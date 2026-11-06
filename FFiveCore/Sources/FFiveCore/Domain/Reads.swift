import Foundation

public struct ExerciseListing: Hashable, Identifiable {
    public let id: ExerciseID
    public let name: String
    public let muscle: Muscle
    public let info: ExerciseInfo?

    public var equipment: String { info?.equipment.displayName ?? "Custom" }

    /// Custom exercises always fit, since the lifter made them.
    public func fits(_ equipment: Set<Equipment>) -> Bool {
        info.map { equipment.contains($0.equipment) } ?? true
    }

    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// Finished sessions this calendar week and in all.
public struct WeekStats: Equatable {
    public let thisWeek: Int
    public let time: TimeInterval
    public let allTime: Int
}

public struct StrengthSeries: Identifiable, Hashable {
    public struct Point: Identifiable, Hashable {
        public struct ID: Hashable {
            public let exercise: ExerciseID
            public let date: Date
        }

        public let id: ID
        public let value: Double
        public let bestSet: String

        public var date: Date { id.date }
    }

    public let id: ExerciseID
    public let name: String
    public let muscle: Muscle?
    public let points: [Point]

    public var latest: Double { points.last?.value ?? 0 }
    public var change: Double { latest - (points.first?.value ?? 0) }
}
