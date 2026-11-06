import Foundation

/// A logged working set against the working set in the same place last session. Last session's set is moved to the
/// load lifted today, so a heavier or lighter set is judged by the reps last session's strength gives at that load.
public struct SetComparison: Equatable {
    public enum Outcome: Equatable {
        case improved, maintained, regressed
    }

    public let outcome: Outcome
    public let previous: LoggedSet
    /// The reps `previous` stands for at today's weight, to the nearest rep.
    public let expectedReps: Int

    init?(_ current: LoggedSet, against previous: LoggedSet, loading: Loading, rir: Int) {
        guard let reps = Self.reps(of: previous, at: current.weight, loading: loading, rir: rir) else { return nil }
        outcome = current.reps > reps ? .improved : current.reps < reps ? .regressed : .maintained
        self.previous = previous
        expectedReps = reps
    }

    /// Nil when the loads differ and the moved load is unknown, as on a bodyweight lift with no body weight.
    private static func reps(of previous: LoggedSet, at weight: Double, loading: Loading, rir: Int) -> Int? {
        if weight == previous.weight { return previous.reps }
        guard let from = loading.movedLoad(of: previous.weight), let to = loading.movedLoad(of: weight) else {
            return nil
        }
        guard from > 0, to > 0 else { return previous.reps }
        let oneRepMax = Progression.estimatedOneRepMax(weight: from, reps: previous.reps, rir: rir)
        return max(0, Int((30 * (oneRepMax / to - 1)).rounded()) - rir)
    }
}

extension Exercise {
    /// Each logged working set here against the working set in the same position of `previous`, keyed by the set.
    /// Myoreps and other set types that say nothing about progression are left out of both sides before matching.
    public func comparisons(with previous: Exercise?) -> [ObjectIdentifier: SetComparison] {
        let loading = loading
        let rir = workout?.effortRIR ?? 0
        let before = previous?.sortedSets.compactMap(\.logged) ?? []
        var result: [ObjectIdentifier: SetComparison] = [:]
        for (set, last) in zip(sortedSets.filter { $0.logged != nil }, before) {
            if let logged = set.logged,
                let comparison = SetComparison(logged, against: last, loading: loading, rir: rir)
            {
                result[ObjectIdentifier(set)] = comparison
            }
        }
        return result
    }
}
