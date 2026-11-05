import Foundation
import SwiftData

/// The latest estimated 1RM per exercise, read from finished history in one fetch so a plan never fetches
/// per exercise. Open sessions are left out on purpose: a lift counts once its session is finished.
struct PlanningSnapshot {
    private let latest: [ExerciseID: (startDate: Date, oneRepMax: Double)]

    static let empty = PlanningSnapshot(latest: [:])

    private init(latest: [ExerciseID: (startDate: Date, oneRepMax: Double)]) {
        self.latest = latest
    }

    init(context: ModelContext) {
        var latest: [ExerciseID: (startDate: Date, oneRepMax: Double)] = [:]
        var descriptor = Workout.history
        descriptor.relationshipKeyPathsForPrefetching = [\.exercises]
        let history = ((try? context.fetch(descriptor)) ?? []).sorted { $0.startDate > $1.startDate }
        for workout in history {
            for exercise in workout.exercises {
                let key = exercise.key
                if let hit = latest[key], hit.startDate > workout.startDate { continue }
                guard let strongest = exercise.strongestSet else { continue }
                // Newest first, so a hit left here shares this start date: the heavier estimate wins.
                if let hit = latest[key], hit.oneRepMax >= strongest.oneRepMax { continue }
                latest[key] = (workout.startDate, strongest.oneRepMax)
            }
        }
        self.latest = latest
    }

    func latestOneRepMax(of key: ExerciseID) -> Double? {
        latest[key]?.oneRepMax
    }
}
