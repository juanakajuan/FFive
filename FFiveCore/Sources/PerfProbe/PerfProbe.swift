@testable import FFiveCore
import Foundation
import SwiftData

@main
struct PerfProbe {
    static let budgetSize = 156
    static let scaleSize = 468
    static let sizes = [0, budgetSize, scaleSize]
    static let budgetMillis = 20.0
    static let budgetScaleFactor = 3.0
    static let runs = 7
    static let writes = 100
    static let lifts: [(name: String, muscle: Muscle)] = [
        ("Bench Press", .chest), ("Cable Fly", .chest), ("Lat Pulldown", .back),
        ("Barbell Row", .back), ("Calf Raise", .calves), ("Incline Dumbbell Press", .chest),
    ]

    @MainActor
    static func main() {
        let enforceBudget = !CommandLine.arguments.contains("--no-budget")
        let clock = ContinuousClock()
        var medians: [Int: Double] = [:]
        var stores: [Int: (Store, Mesocycle)] = [:]
        for size in sizes {
            let (store, meso) = seeded(finishedWorkouts: size)
            stores[size] = (store, meso)
            var millis: [Double] = []
            for _ in 0..<runs {
                millis.append(clock.measure { _ = store.weeklyVolume(meso, week: 0) }.milliseconds)
            }
            let median = millis.sorted()[runs / 2]
            medians[size] = median
            print("perf-probe: weeklyVolume median \(format(median)) ms at \(size) finished workouts (\(runs) runs)")
        }

        let (store, meso) = stores[budgetSize]!
        let session = store.buildSession(meso, at: SessionKey(week: 0, dayIndex: 0))
        let set = session.sortedExercises[0].sortedSets[0]
        var storeLog: [Double] = []
        for index in 0..<writes {
            storeLog.append(clock.measure { store.log(set, done: index.isMultiple(of: 2)) }.milliseconds)
        }
        print("perf-probe: set-done median \(format(storeLog.sorted()[writes / 2])) ms per write over \(writes) writes (store.log)")

        guard enforceBudget else { return }
        let at156 = medians[budgetSize]!
        let atScale = medians[scaleSize]!
        if at156 > budgetMillis {
            print("perf-probe: FAIL weeklyVolume median \(format(at156)) ms at \(budgetSize) exceeds \(format(budgetMillis)) ms")
            exit(1)
        }
        if atScale > budgetScaleFactor * at156 {
            print("perf-probe: FAIL weeklyVolume median \(format(atScale)) ms at \(scaleSize) exceeds \(format(budgetScaleFactor)) x the \(format(at156)) ms at \(budgetSize)")
            exit(1)
        }
    }

    /// A fresh store with `finishedWorkouts` sessions of the six lifts behind a 4-day draft that has no session built.
    @MainActor
    private static func seeded(finishedWorkouts: Int) -> (Store, Mesocycle) {
        let store = Store(inMemory: true)
        let context = store.context
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        for index in 0..<finishedWorkouts {
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
        try! store.startMesocycle(draft)
        let meso = try! context.fetch(Mesocycle.active).first!
        return (store, meso)
    }

    private static func format(_ millis: Double) -> String {
        millis.formatted(.number.precision(.fractionLength(2)))
    }
}

extension Duration {
    var milliseconds: Double {
        Double(components.seconds) * 1000 + Double(components.attoseconds) / 1e15
    }
}
