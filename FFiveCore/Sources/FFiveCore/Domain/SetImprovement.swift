import Foundation

/// A logged working set that beats the working set in the same place last session: at least the reps at at least the
/// weight, and more of one.
public struct SetImprovement: Equatable {
    public let previous: LoggedSet
    public let current: LoggedSet

    init?(_ current: LoggedSet, over previous: LoggedSet) {
        let atLeast = current.weight >= previous.weight && current.reps >= previous.reps
        guard atLeast, current != previous else { return nil }
        self.previous = previous
        self.current = current
    }

    public var addedReps: Int { current.reps - previous.reps }
    public var addedWeight: Double { current.weight - previous.weight }
}

extension Exercise {
    /// Each logged working set here that beats the working set in the same position of `previous`, keyed by the set.
    /// Myoreps and other set types that say nothing about progression are left out of both sides before matching.
    public func improvements(over previous: Exercise?) -> [ObjectIdentifier: SetImprovement] {
        let before = previous?.sortedSets.compactMap(\.logged) ?? []
        let now = sortedSets.filter { $0.logged != nil }
        var result: [ObjectIdentifier: SetImprovement] = [:]
        for (set, last) in zip(now, before) {
            if let logged = set.logged, let improvement = SetImprovement(logged, over: last) {
                result[ObjectIdentifier(set)] = improvement
            }
        }
        return result
    }
}
