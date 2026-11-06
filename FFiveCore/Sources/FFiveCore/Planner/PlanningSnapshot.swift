import Foundation
import SwiftData

struct PlanningSnapshot {
    private let latest: [ExerciseID: Double]
    /// The body weight of the most recent session that has one, finished or not.
    let bodyweight: Double?
    private let customs: [ExerciseID: ExerciseInfo]

    static let empty = PlanningSnapshot(latest: [:], bodyweight: nil, customs: [:])

    private init(latest: [ExerciseID: Double], bodyweight: Double?, customs: [ExerciseID: ExerciseInfo]) {
        self.latest = latest
        self.bodyweight = bodyweight
        self.customs = customs
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
        let customs = Dictionary(
            CustomExercise.all(in: context).map { ($0.key, $0.info) }, uniquingKeysWith: { first, _ in first })
        self.init(latest: latest, bodyweight: (try? context.fetch(entered))?.first?.bodyweight, customs: customs)
    }

    func info(_ key: ExerciseID) -> ExerciseInfo? { ExerciseCatalog.info(key) ?? customs[key] }

    func loading(for key: ExerciseID, bodyweight: Double?) -> Loading {
        Loading(equipment: info(key)?.equipment, bodyweight: bodyweight)
    }

    func repRange(for key: ExerciseID) -> ClosedRange<Int> { info(key)?.repRange ?? 8...12 }

    func latestOneRepMax(of key: ExerciseID) -> Double? {
        latest[key]
    }
}
