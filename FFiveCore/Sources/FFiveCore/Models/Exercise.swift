import Foundation
import SwiftData

@Model
public final class Exercise {
    public internal(set) var name: String
    public internal(set) var exerciseKey: String?
    public var order: Int
    /// Where this exercise sits in the plan built from this session. Nil means the same as `order`.
    var plannedOrder: Int?
    public internal(set) var workout: Workout?
    @Relationship(deleteRule: .cascade, inverse: \SetEntry.exercise)
    public internal(set) var sets: [SetEntry] = []
    var muscleRaw: String?
    public internal(set) var note: String?

    public init(name: String, order: Int, muscle: Muscle? = nil) {
        self.name = name
        self.exerciseKey = ExerciseID(folding: name).rawValue
        self.order = order
        self.muscleRaw = muscle?.rawValue
    }

    public var key: ExerciseID { exerciseKey.map(ExerciseID.init(rawValue:)) ?? ExerciseID(folding: name) }

    func rename(_ name: String) {
        self.name = name
        exerciseKey = ExerciseID(folding: name).rawValue
    }

    public var sortedSets: [SetEntry] { sets.sorted { $0.order < $1.order } }
    public var isLogged: Bool { !sets.isEmpty && sets.allSatisfy(\.isDone) }
    public var info: ExerciseInfo? { ExerciseCatalog.info(key) }

    /// Rows logged before muscles were stored resolve through the catalog.
    public internal(set) var muscle: Muscle? {
        get { muscleRaw.flatMap(Muscle.init(rawValue:)) ?? info?.muscle }
        set { muscleRaw = newValue?.rawValue }
    }

    public var repRange: ClosedRange<Int> { ExerciseCatalog.repRange(for: key) }

    func increment(_ unit: WeightUnit) -> Double {
        ExerciseCatalog.increment(for: key, unit: unit)
    }

    /// Appends a set shaped like the last one, so the lifter edits instead of retyping.
    func addSet() {
        let last = sortedSets.last
        let set = SetEntry(reps: last?.reps ?? 10, weight: last?.weight ?? 0, order: (last?.order ?? -1) + 1)
        set.targetWeight = last?.targetWeight
        set.targetReps = last?.targetReps
        sets.append(set)
    }

    func remove(_ set: SetEntry, in context: ModelContext) {
        sets.removeAll { $0 === set }
        context.delete(set)
    }

    /// The done, loaded set with the highest estimated 1RM, or nil when no set says anything about strength.
    public var strongestSet: (entry: SetEntry, oneRepMax: Double)? {
        guard let rir = workout?.effortRIR else { return nil }
        return sets.filter { $0.isDone && $0.weight > 0 && $0.reps > 0 }
            .map { ($0, Progression.estimatedOneRepMax(weight: $0.weight, reps: $0.reps, rir: rir)) }
            .max { $0.1 < $1.1 }
    }
}

extension Exercise {
    func setNote(_ text: String, in context: ModelContext) {
        if PinnedNote.find(named: name, in: context) != nil {
            PinnedNote.set(text, for: name, in: context)
        } else {
            note = text.noteText
        }
    }

    func deleteNote(in context: ModelContext) {
        PinnedNote.delete(for: name, in: context)
        note = nil
    }

    func pinNote(in context: ModelContext) {
        guard let note else { return }
        PinnedNote.set(note, for: name, in: context)
        self.note = nil
    }

    func unpinNote(in context: ModelContext) {
        note = PinnedNote.find(named: name, in: context)?.text
        PinnedNote.delete(for: name, in: context)
    }
}
