import Foundation
import SwiftData

@Model
public final class DaySlot {
    var exerciseName: String = ""
    var exerciseKey: String?
    var muscleRaw: String = ""
    public var order: Int = 0
    public var day: MesoDay?

    init(exerciseName: String, muscle: Muscle, order: Int) {
        self.exerciseName = exerciseName
        self.exerciseKey = ExerciseID(folding: exerciseName).rawValue
        self.muscleRaw = muscle.rawValue
        self.order = order
    }

    public var muscle: Muscle? { Muscle(rawValue: muscleRaw) }

    /// Rows written before the key column existed fold their name until the store backfills them.
    var key: ExerciseID { exerciseKey.map(ExerciseID.init(rawValue:)) ?? ExerciseID(folding: exerciseName) }
}
