import FFiveCore
import Foundation
import SwiftData

@main
struct PerfProbe {
    static let historyCount = 156
    static let runs = 5

    @MainActor
    static func main() {
        let context = ModelContext(AppStore.makeContainer(inMemory: true))
        let lifts: [(name: String, muscle: Muscle)] = [
            ("Bench Press", .chest), ("Cable Fly", .chest), ("Lat Pulldown", .back),
            ("Barbell Row", .back), ("Calf Raise", .calves), ("Incline Dumbbell Press", .chest),
        ]

        let start = Date(timeIntervalSince1970: 1_700_000_000)
        for index in 0..<historyCount {
            let date = start + Double(index) * 86_400
            let workout = Workout(name: "History \(index)", startDate: date)
            context.insert(workout)
            for (order, lift) in lifts.enumerated() {
                let exercise = Exercise(name: lift.name, order: order, muscle: lift.muscle)
                workout.exercises.append(exercise)
                for setOrder in 0..<3 {
                    let set = SetEntry(reps: 8, weight: 100, order: setOrder)
                    set.isDone = true
                    exercise.sets.append(set)
                }
            }
            workout.endDate = date + 3600
        }

        var draft = MesoDraft(template: nil)
        draft.days = (0..<4).map { day in
            .init(name: "Day \(day + 1)", slots: lifts.map { .init(exercise: $0.name, muscle: $0.muscle) })
        }
        let meso = MesoPlanner.start(draft, in: context)

        var millis: [Double] = []
        for _ in 0..<runs {
            let clock = ContinuousClock()
            let elapsed = clock.measure { _ = MesoPlanner.weeklyVolume(meso, week: 0, unit: .lb, context: context) }
            millis.append(Double(elapsed.components.seconds) * 1000 + Double(elapsed.components.attoseconds) / 1e15)
        }
        let median = millis.sorted()[runs / 2]
        print("perf-probe: weeklyVolume median \(Int(median.rounded())) ms over \(runs) runs, \(historyCount) finished workouts")
    }
}
