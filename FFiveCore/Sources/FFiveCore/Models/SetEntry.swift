import Foundation
import SwiftData

@Model
public final class SetEntry {
    public var reps: Int
    public var weight: Double
    public internal(set) var isDone: Bool = false
    public var order: Int
    public internal(set) var exercise: Exercise?
    public var targetWeight: Double?
    public var targetReps: Int?

    public init(reps: Int, weight: Double, order: Int) {
        self.reps = reps
        self.weight = weight
        self.order = order
    }

    /// A prescribed set, prefilled with its target so checking it off logs the target.
    public convenience init(target: SetTarget, order: Int) {
        self.init(reps: target.reps ?? 0, weight: target.weight ?? 0, order: order)
        targetWeight = target.weight
        targetReps = target.reps
    }

    var target: SetTarget { SetTarget(weight: targetWeight, reps: targetReps) }
    var logged: LoggedSet? { isDone ? LoggedSet(weight: weight, reps: reps) : nil }
}
