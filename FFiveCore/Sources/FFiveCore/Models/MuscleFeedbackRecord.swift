import Foundation
import SwiftData

@Model
public final class MuscleFeedbackRecord {
    public var muscleRaw: String = ""
    var sorenessRaw: Int?
    var pumpRaw: Int?
    var workloadRaw: Int?
    var jointPainRaw: Int?
    public internal(set) var workout: Workout?

    init(muscle: Muscle) {
        self.muscleRaw = muscle.rawValue
    }

    public var muscle: Muscle? { Muscle(rawValue: muscleRaw) }

    public var value: MuscleFeedback {
        get {
            MuscleFeedback(
                soreness: sorenessRaw.flatMap(Soreness.init(rawValue:)),
                pump: pumpRaw.flatMap(Pump.init(rawValue:)),
                workload: workloadRaw.flatMap(Workload.init(rawValue:)),
                jointPain: jointPainRaw.flatMap(JointPain.init(rawValue:)))
        }
        set {
            sorenessRaw = newValue.soreness?.rawValue
            pumpRaw = newValue.pump?.rawValue
            workloadRaw = newValue.workload?.rawValue
            jointPainRaw = newValue.jointPain?.rawValue
        }
    }
}
