import Foundation

/// A logged working set against what was expected of it: its target, or the working set in the same place last
/// session when it has no target. The expectation is moved to the load actually lifted, so a set at another load in
/// the target range is judged by the reps that load should give.
public struct SetComparison: Equatable {
    public enum Outcome: Equatable {
        case below, met, above
    }

    public enum Basis: Equatable {
        case target, lastSession
    }

    public let outcome: Outcome
    public let basis: Basis
    public let expected: LoggedSet
    /// The reps `expected` stands for at the logged weight, to the nearest rep.
    public let expectedReps: Int

    init?(_ current: LoggedSet, expected: LoggedSet, basis: Basis, loading: Loading, rir: Int) {
        guard let reps = Self.reps(of: expected, at: current.weight, loading: loading, rir: rir) else { return nil }
        outcome = current.reps < reps ? .below : current.reps > reps ? .above : .met
        self.basis = basis
        self.expected = expected
        expectedReps = reps
    }

    /// Nil when the loads differ and the moved load is unknown, as on a bodyweight lift with no body weight.
    private static func reps(of expected: LoggedSet, at weight: Double, loading: Loading, rir: Int) -> Int? {
        if weight == expected.weight { return expected.reps }
        guard let from = loading.movedLoad(of: expected.weight), let to = loading.movedLoad(of: weight) else {
            return nil
        }
        guard from > 0, to > 0 else { return expected.reps }
        let oneRepMax = Progression.estimatedOneRepMax(weight: from, reps: expected.reps, rir: rir)
        return max(0, Int((30 * (oneRepMax / to - 1)).rounded()) - rir)
    }
}

extension Exercise {
    /// Each logged working set here against its target, or against the working set in the same position of
    /// `previous` when it has none, keyed by the set. Myoreps and other set types that say nothing about progression
    /// are left out, and out of the matching with `previous`.
    public func comparisons(with previous: Exercise?) -> [ObjectIdentifier: SetComparison] {
        let loading = loading
        let rir = workout?.effortRIR ?? 0
        let before = previous?.sortedSets.compactMap(\.logged) ?? []
        var result: [ObjectIdentifier: SetComparison] = [:]
        for (index, set) in sortedSets.filter({ $0.logged != nil }).enumerated() {
            guard let logged = set.logged else { continue }
            let comparison: SetComparison? =
                if let weight = set.targetWeight, let reps = set.targetReps {
                    SetComparison(
                        logged, expected: LoggedSet(weight: weight, reps: reps), basis: .target, loading: loading,
                        rir: rir)
                } else if index < before.count {
                    SetComparison(logged, expected: before[index], basis: .lastSession, loading: loading, rir: rir)
                } else {
                    nil
                }
            result[ObjectIdentifier(set)] = comparison
        }
        return result
    }
}
