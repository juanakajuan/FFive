import Foundation
import SwiftData

/// A run of consecutive finished sessions of one exercise that share a mesocycle. Quick workouts have none.
public struct ExerciseHistoryGroup: Identifiable {
    public let mesocycle: Mesocycle?
    /// Newest first. Each has at least one logged set and a finished workout.
    public let sessions: [Exercise]

    public var id: PersistentIdentifier { sessions[0].persistentModelID }

    /// Every finished session of the exercise with a logged set, newest first,
    /// split wherever the mesocycle changes so each group reads as one block.
    static func groups(of key: ExerciseID, in context: ModelContext) -> [ExerciseHistoryGroup] {
        let raw = key.rawValue
        let sessions =
            ((try? context.fetch(FetchDescriptor<Exercise>(predicate: #Predicate { $0.exerciseKey == raw })))
            ?? [])
            .filter { $0.workout?.isFinished == true && $0.sets.contains(where: \.isDone) }
            .sorted { ($0.workout?.startDate ?? .distantPast) > ($1.workout?.startDate ?? .distantPast) }
        var groups: [ExerciseHistoryGroup] = []
        for session in sessions {
            let meso = session.workout?.mesocycle
            if let last = groups.last, last.mesocycle === meso {
                groups[groups.count - 1] = ExerciseHistoryGroup(mesocycle: meso, sessions: last.sessions + [session])
            } else {
                groups.append(ExerciseHistoryGroup(mesocycle: meso, sessions: [session]))
            }
        }
        return groups
    }
}
