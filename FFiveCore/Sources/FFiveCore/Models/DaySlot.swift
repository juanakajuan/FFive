import Foundation
import SwiftData

@Model
public final class DaySlot {
    var exerciseName: String = ""
    public var muscleRaw: String = ""
    public var order: Int = 0
    public var day: MesoDay?

    init(exerciseName: String, muscle: Muscle, order: Int) {
        self.exerciseName = exerciseName
        self.muscleRaw = muscle.rawValue
        self.order = order
    }

    public var muscle: Muscle? { Muscle(rawValue: muscleRaw) }
}
