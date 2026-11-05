import Foundation
import SwiftData

struct PlanningSnapshot {
    private let latest: [ExerciseID: Double]

    static let empty = PlanningSnapshot(latest: [:])

    private init(latest: [ExerciseID: Double]) {
        self.latest = latest
    }

    init(context: ModelContext) {
        var descriptor = Workout.history
        descriptor.relationshipKeyPathsForPrefetching = [\.exercises]
        var latest: [ExerciseID: Double] = [:]
        for workout in (try? context.fetch(descriptor)) ?? [] {
            for exercise in workout.sortedExercises {
                let key = exercise.key
                guard latest[key] == nil, let strongest = exercise.strongestSet else { continue }
                latest[key] = strongest.oneRepMax
            }
        }
        self.latest = latest
    }

    func latestOneRepMax(of key: ExerciseID) -> Double? {
        latest[key]
    }
}
