@testable import FFiveCore
import Foundation
import SwiftData

@main
struct PerfProbe {
    static let historyCount = 156
    static let runs = 5
    static let writes = 100

    @MainActor
    static func main() {
        let store = Store(inMemory: true)
        let context = store.context
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

        let clock = ContinuousClock()
        var millis: [Double] = []
        for _ in 0..<runs {
            let elapsed = clock.measure { _ = MesoPlanner.weeklyVolume(meso, week: 0, unit: .lb, context: context) }
            millis.append(elapsed.milliseconds)
        }
        print("perf-probe: weeklyVolume median \(Int(millis.sorted()[runs / 2].rounded())) ms over \(runs) runs, \(historyCount) finished workouts")

        let session = MesoPlanner.workout(for: meso, at: SessionKey(week: 0, dayIndex: 0), unit: .lb, in: context)
        try? context.save()
        let set = session.sortedExercises[0].sortedSets[0]
        var toggleSave: [Double] = []
        for _ in 0..<writes {
            toggleSave.append(clock.measure {
                set.isDone.toggle()
                try? context.save()
            }.milliseconds)
        }
        print("perf-probe: set-done median \(toggleSave.sorted()[writes / 2].formatted(.number.precision(.fractionLength(2)))) ms per write over \(writes) writes (toggle+save, the trunk write)")
        #if !TRUNK_WRITE
        var storeLog: [Double] = []
        for index in 0..<writes {
            storeLog.append(clock.measure { store.log(set, done: index.isMultiple(of: 2)) }.milliseconds)
        }
        print("perf-probe: set-done median \(storeLog.sorted()[writes / 2].formatted(.number.precision(.fractionLength(2)))) ms per write over \(writes) writes (store.log)")
        #endif
    }
}

extension Duration {
    var milliseconds: Double {
        Double(components.seconds) * 1000 + Double(components.attoseconds) / 1e15
    }
}
