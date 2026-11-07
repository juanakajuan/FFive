import Foundation
import SwiftData

@Model
public final class DaySlot {
    var exerciseName: String = ""
    var exerciseKey: String?
    var muscleRaw: String = ""
    public var order: Int = 0
    public var day: MesoDay?
    /// JSON of `[SetTarget]` the first session of this slot starts from, carried from a copied block. Nil plans it
    /// fresh.
    var startingTargetsData: Data?

    init(exerciseName: String, muscle: Muscle, order: Int) {
        self.exerciseName = exerciseName
        self.exerciseKey = ExerciseID(folding: exerciseName).rawValue
        self.muscleRaw = muscle.rawValue
        self.order = order
    }

    public var muscle: Muscle? { Muscle(rawValue: muscleRaw) }

    var startingTargets: [SetTarget]? {
        get { startingTargetsData.flatMap { try? JSONDecoder().decode([SetTarget].self, from: $0) } }
        set { startingTargetsData = newValue.flatMap { try? JSONEncoder().encode($0) } }
    }

    var key: ExerciseID { exerciseKey.map(ExerciseID.init(rawValue:)) ?? ExerciseID(folding: exerciseName) }
}
