import Foundation
import SwiftData

/// An exercise the lifter defined. Its identity is the folded name, like a catalog exercise, so logged rows and
/// slots find it by `ExerciseID`. Hidden covers both a lifter's choice and an archive after delete.
@Model
public final class CustomExercise {
    public internal(set) var name: String = ""
    public internal(set) var exerciseKey: String = ""
    var muscleRaw: String = ""
    var equipmentRaw: String = Equipment.machine.rawValue
    public internal(set) var minReps: Int = 8
    public internal(set) var maxReps: Int = 12
    public internal(set) var cue: String?
    public internal(set) var isHidden: Bool = false

    init(name: String, muscle: Muscle, equipment: Equipment = .machine, repRange: ClosedRange<Int> = 8...12) {
        self.name = name
        exerciseKey = ExerciseID(folding: name).rawValue
        muscleRaw = muscle.rawValue
        equipmentRaw = equipment.rawValue
        minReps = repRange.lowerBound
        maxReps = repRange.upperBound
    }

    public var key: ExerciseID { ExerciseID(rawValue: exerciseKey) }
    public var muscle: Muscle { Muscle(rawValue: muscleRaw) ?? .chest }
    public var equipment: Equipment { Equipment(rawValue: equipmentRaw) ?? .machine }
    public var repRange: ClosedRange<Int> { minReps...max(minReps, maxReps) }

    public var info: ExerciseInfo {
        ExerciseInfo(name: name, muscle: muscle, equipment: equipment, repRange: repRange, cue: cue)
    }

    func apply(_ draft: CustomExerciseDraft) {
        name = draft.name
        exerciseKey = ExerciseID(folding: draft.name).rawValue
        muscleRaw = draft.muscle.rawValue
        equipmentRaw = draft.equipment.rawValue
        minReps = draft.minReps
        maxReps = draft.maxReps
        cue = draft.cue.noteText
    }
}

extension CustomExercise {
    static func find(_ key: ExerciseID, in context: ModelContext) -> CustomExercise? {
        let raw = key.rawValue
        return try? context.fetch(FetchDescriptor<CustomExercise>(predicate: #Predicate { $0.exerciseKey == raw }))
            .first
    }

    static func all(in context: ModelContext) -> [CustomExercise] {
        (try? context.fetch(FetchDescriptor<CustomExercise>())) ?? []
    }

    /// Records a name that is not in the catalog with today's defaults, so lifts logged before custom exercises
    /// were records keep their behavior. A no-op for catalog names and names already recorded.
    static func ensure(named name: String, muscle: Muscle, in context: ModelContext) {
        let key = ExerciseID(folding: name)
        guard ExerciseCatalog.info(key) == nil, find(key, in: context) == nil else { return }
        context.insert(CustomExercise(name: name, muscle: muscle))
    }
}

/// What the editor collects, in the shapes its fields bind to. `Store.saveCustomExercise` normalizes it before it
/// reaches the record.
public struct CustomExerciseDraft: Equatable {
    public var name: String
    public var muscle: Muscle
    public var equipment: Equipment
    public var minReps: Int
    public var maxReps: Int
    public var cue: String

    public init(
        name: String = "", muscle: Muscle = .chest, equipment: Equipment = .machine,
        minReps: Int = 8, maxReps: Int = 12, cue: String = ""
    ) {
        self.name = name
        self.muscle = muscle
        self.equipment = equipment
        self.minReps = minReps
        self.maxReps = maxReps
        self.cue = cue
    }

    public init(_ exercise: CustomExercise) {
        let reps = exercise.repRange
        self.init(
            name: exercise.name, muscle: exercise.muscle, equipment: exercise.equipment,
            minReps: reps.lowerBound, maxReps: reps.upperBound, cue: exercise.cue ?? "")
    }
}
