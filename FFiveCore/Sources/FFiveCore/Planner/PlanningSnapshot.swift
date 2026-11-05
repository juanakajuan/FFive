import Foundation
import SwiftData

struct PlanningSnapshot {
    private let latest: [ExerciseID: Double]
    /// The body weight of the most recent session that has one, finished or not.
    let bodyweight: Double?

    static let empty = PlanningSnapshot(latest: [:], bodyweight: nil)

    private init(latest: [ExerciseID: Double], bodyweight: Double?) {
        self.latest = latest
        self.bodyweight = bodyweight
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
        var entered = FetchDescriptor<Workout>(
            predicate: #Predicate { $0.bodyweight != nil }, sortBy: [SortDescriptor(\.startDate, order: .reverse)])
        entered.fetchLimit = 1
        self.init(latest: latest, bodyweight: (try? context.fetch(entered))?.first?.bodyweight)
    }

    func latestOneRepMax(of key: ExerciseID) -> Double? {
        latest[key]
    }
}
