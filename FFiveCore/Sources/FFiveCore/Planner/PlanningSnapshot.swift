import Foundation
import SwiftData

/// The latest estimated 1RM per exercise, read from finished history in one fetch so a plan never fetches
/// per exercise. Open sessions are left out on purpose: a lift counts once its session is finished.
struct PlanningSnapshot {
    private let latest: [ExerciseID: Double]

    static let empty = PlanningSnapshot(latest: [:])

    private init(latest: [ExerciseID: Double]) {
        self.latest = latest
    }

    init(context: ModelContext) {
        let descriptor = FetchDescriptor<Exercise>(
            predicate: #Predicate { $0.workout?.endDate != nil },
            sortBy: [SortDescriptor(\.workout?.startDate, order: .reverse), SortDescriptor(\.order)])
        var latest: [ExerciseID: Double] = [:]
        for exercise in (try? context.fetch(descriptor)) ?? [] {
            let key = exercise.key
            guard latest[key] == nil, let strongest = exercise.strongestSet else { continue }
            latest[key] = strongest.oneRepMax
        }
        self.latest = latest
    }

    func latestOneRepMax(of key: ExerciseID) -> Double? {
        latest[key]
    }
}
