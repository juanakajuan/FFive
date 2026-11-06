import Foundation
import SwiftData

@Model
public final class SetEntry {
    public var reps: Int
    public var weight: Double
    public private(set) var isDone: Bool = false
    public private(set) var isSkipped: Bool = false
    public var order: Int
    public internal(set) var exercise: Exercise?
    public var targetWeight: Double?
    public var targetReps: Int?
    var typeRaw: String = SetType.regular.rawValue

    public internal(set) var type: SetType {
        get { SetType(rawValue: typeRaw) ?? .regular }
        set { typeRaw = newValue.rawValue }
    }

    public init(reps: Int, weight: Double, order: Int) {
        self.reps = reps
        self.weight = weight
        self.order = order
    }

    public convenience init(target: SetTarget, order: Int) {
        self.init(reps: target.reps ?? 0, weight: target.weight ?? 0, order: order)
        targetWeight = target.weight
        targetReps = target.reps
    }

    public internal(set) var status: SetStatus {
        get { isDone ? .done : isSkipped ? .skipped : .pending }
        set {
            isDone = newValue == .done
            isSkipped = newValue == .skipped
        }
    }

    /// A set is logged only once its reps are entered, and its weight too unless the lift is bodyweight, where 0 means
    /// body weight alone.
    public var hasEntry: Bool { reps > 0 && (weight != 0 || exercise?.isBodyweight == true) }

    /// Sets log in order: a set waits until every earlier set is logged or skipped, and a logged set is unlogged only
    /// while no later set is logged.
    public var canToggleLog: Bool {
        let sets = exercise?.sortedSets ?? []
        if isDone { return !sets.contains { $0.order > order && $0.isDone } }
        return hasEntry && !sets.contains { $0.order < order && $0.status == .pending }
    }

    var target: SetTarget { SetTarget(weight: targetWeight, reps: targetReps) }
    var logged: LoggedSet? { isDone && type.countsTowardProgression ? LoggedSet(weight: weight, reps: reps) : nil }
}

/// A skipped set was let go on purpose: it no longer waits to be logged, and it says nothing about strength.
public enum SetStatus: Equatable {
    case pending, done, skipped
}
