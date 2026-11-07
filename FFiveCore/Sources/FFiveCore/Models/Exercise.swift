import Foundation
import SwiftData

@Model
public final class Exercise {
    public internal(set) var name: String = ""
    public internal(set) var exerciseKey: String?
    public var order: Int = 0
    /// Where this exercise sits in the plan built from this session. Nil means the same as `order`.
    var plannedOrder: Int?
    /// The exercise later weeks are planned with, set by a session-only swap. Nil means this one.
    var plannedName: String?
    var plannedMuscleRaw: String?
    public internal(set) var workout: Workout?
    @Relationship(deleteRule: .cascade, originalName: "sets", inverse: \SetEntry.exercise)
    var storedSets: [SetEntry]?
    var muscleRaw: String?
    public internal(set) var note: String?

    public internal(set) var sets: [SetEntry] {
        get { storedSets ?? [] }
        set { storedSets = newValue }
    }

    public init(name: String, order: Int, muscle: Muscle? = nil) {
        self.name = name
        self.exerciseKey = ExerciseID(folding: name).rawValue
        self.order = order
        self.muscleRaw = muscle?.rawValue
    }

    public var key: ExerciseID { exerciseKey.map(ExerciseID.init(rawValue:)) ?? ExerciseID(folding: name) }
    /// The exercise this one hands on to later weeks: itself, or what a session-only swap replaced.
    var planned: (name: String, key: ExerciseID, muscle: Muscle?) {
        guard let plannedName else { return (name, key, muscle) }
        return (plannedName, ExerciseID(folding: plannedName), plannedMuscleRaw.flatMap(Muscle.init(rawValue:)))
    }

    func rename(_ name: String) {
        self.name = name
        exerciseKey = ExerciseID(folding: name).rawValue
    }

    public var sortedSets: [SetEntry] { sets.sorted { $0.order < $1.order } }
    /// Every set is logged or skipped.
    public var isLogged: Bool { !sets.isEmpty && !sets.contains { $0.status == .pending } }
    /// The catalog entry, else the lifter's own definition. Catalog hits never fetch.
    public var info: ExerciseInfo? {
        ExerciseCatalog.info(key) ?? modelContext.flatMap { CustomExercise.find(key, in: $0) }?.info
    }

    /// Rows logged before muscles were stored resolve through the catalog.
    public internal(set) var muscle: Muscle? {
        get { muscleRaw.flatMap(Muscle.init(rawValue:)) ?? info?.muscle }
        set { muscleRaw = newValue?.rawValue }
    }

    public var repRange: ClosedRange<Int> { info?.repRange ?? 8...12 }

    func laterSets(matchingWeightOf set: SetEntry) -> [SetEntry] {
        sortedSets.filter { $0.order > set.order && $0.status != .done && $0.weight == set.weight }
    }

    func addSet() {
        let last = sortedSets.last
        let set = SetEntry(reps: last?.reps ?? 10, weight: last?.weight ?? 0, order: (last?.order ?? -1) + 1)
        set.targetWeight = last?.targetWeight
        set.targetReps = last?.targetReps
        set.type = last?.type ?? .regular
        sets.append(set)
    }

    func skipRemainingSets() {
        for set in sets where set.status == .pending { set.status = .skipped }
    }

    func remove(_ set: SetEntry, in context: ModelContext) {
        sets.removeAll { $0 === set }
        context.delete(set)
    }

    /// The done regular set with the highest estimated 1RM of its moved load, or nil when no set says anything
    /// about strength. A bodyweight lift needs the workout's body weight to count.
    public var strongestSet: (entry: SetEntry, oneRepMax: Double)? {
        guard let rir = workout?.effortRIR else { return nil }
        let loading = loading
        return sets.compactMap { set -> (SetEntry, Double)? in
            guard set.isDone, set.type.countsTowardProgression, set.reps > 0,
                let moved = loading.movedLoad(of: set.weight), moved > 0
            else { return nil }
            return (set, Progression.estimatedOneRepMax(weight: moved, reps: set.reps, rir: rir))
        }
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
