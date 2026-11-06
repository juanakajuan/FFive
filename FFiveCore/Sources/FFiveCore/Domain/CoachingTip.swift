import Foundation

/// A short piece of Learn guidance shown on an exercise card at the moment it applies.
public enum CoachingTip: String, CaseIterable, Sendable {
    /// Before the first set of an exercise whose next target has no weight yet.
    case startingLoad
    /// Between sets, once one is logged and another waits.
    case rest

    /// At most one tip per card. `startingLoad` comes before any set is logged and `rest` only after, so they
    /// never compete.
    public static func applicable(to exercise: Exercise, dismissed: Set<CoachingTip>) -> CoachingTip? {
        let sets = exercise.sortedSets
        guard let next = sets.first(where: { $0.status == .pending }) else { return nil }
        let tip: CoachingTip
        if sets.contains(where: \.isDone) {
            tip = .rest
        } else if exercise.workout?.phase != nil, next.targetWeight == nil {
            tip = .startingLoad
        } else {
            return nil
        }
        return dismissed.contains(tip) ? nil : tip
    }
}
