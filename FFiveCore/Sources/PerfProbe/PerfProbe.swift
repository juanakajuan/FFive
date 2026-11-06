import Foundation
import SwiftData

@testable import FFiveCore

@main
struct PerfProbe {
    static let budgetSize = 156
    static let scaleSize = 468
    static let sizes = [0, budgetSize, scaleSize]
    static let budgetMillis = 20.0
    static let budgetScaleFactor = 3.0
    static let coldScaleFactor = 4.0
    static let rounds = 15
    static let warmPerRound = 3
    static let writes = 100
    static let lifts: [(name: String, muscle: Muscle)] = [
        ("Bench Press", .chest), ("Cable Fly", .chest), ("Lat Pulldown", .back),
        ("Barbell Row", .back), ("Calf Raise", .calves), ("Incline Dumbbell Press", .chest),
    ]

    @MainActor
    static func main() {
        let enforceBudget = !CommandLine.arguments.contains("--no-budget")
        var stores: [Int: (Store, Mesocycle)] = [:]
        for size in sizes {
            stores[size] = seeded(finishedWorkouts: size)
        }
        var colds: [Int: [Double]] = [:]
        var warms: [Int: [Double]] = [:]
        for _ in 0..<rounds {
            for size in sizes {
                let (store, meso) = stores[size]!
                store.commit()
                colds[size, default: []].append(time { _ = store.weeklyVolume(meso, week: 0) })
                for _ in 0..<warmPerRound {
                    warms[size, default: []].append(time { _ = store.weeklyVolume(meso, week: 0) })
                }
            }
        }
        for size in sizes {
            print(
                "perf-probe: weeklyVolume median \(format(median(warms[size]!))) ms (min \(format(warms[size]!.min()!))) at \(size) finished workouts, \(format(median(colds[size]!))) ms (min \(format(colds[size]!.min()!))) on the first render after a commit"
            )
        }
        print(
            "perf-probe: main-thread CPU time over \(rounds) rounds interleaving the sizes, each a commit, one first render and \(warmPerRound) renders per size; gates use the min"
        )

        let (store, meso) = stores[budgetSize]!
        var strength: [Double] = []
        for _ in 0..<rounds {
            store.commit()
            strength.append(time { _ = store.strengthSeries() })
        }
        print(
            "perf-probe: strengthSeries median \(format(median(strength))) ms (min \(format(strength.min()!))) at \(budgetSize) finished workouts over \(rounds) reads, each after a commit"
        )

        let session = store.buildSession(meso, at: SessionKey(week: 0, dayIndex: 0))
        let set = session.sortedExercises[0].sortedSets[0]
        set.weight = 100
        set.reps = 8
        var storeLog: [Double] = []
        for index in 0..<writes {
            storeLog.append(time { store.log(set, done: index.isMultiple(of: 2)) })
        }
        print("perf-probe: set-done median \(format(median(storeLog))) ms per write over \(writes) writes (store.log)")

        guard enforceBudget else { return }
        var failed = false
        func gate(_ ok: Bool, _ message: String) {
            guard !ok else { return }
            print("perf-probe: FAIL \(message)")
            failed = true
        }
        let warm = warms.mapValues { $0.min()! }
        let cold = colds.mapValues { $0.min()! }
        gate(
            warm[budgetSize]! <= budgetMillis,
            "weeklyVolume min \(format(warm[budgetSize]!)) ms at \(budgetSize) exceeds \(format(budgetMillis)) ms")
        gate(
            warm[scaleSize]! <= budgetScaleFactor * warm[budgetSize]!,
            "weeklyVolume min \(format(warm[scaleSize]!)) ms at \(scaleSize) exceeds \(format(budgetScaleFactor)) x the \(format(warm[budgetSize]!)) ms at \(budgetSize)"
        )
        gate(
            warm[scaleSize]! <= budgetScaleFactor * warm[0]!,
            "weeklyVolume min \(format(warm[scaleSize]!)) ms at \(scaleSize) exceeds \(format(budgetScaleFactor)) x the \(format(warm[0]!)) ms at 0, so a render between commits scales with history"
        )
        gate(
            cold[scaleSize]! <= coldScaleFactor * cold[budgetSize]!,
            "first render after a commit min \(format(cold[scaleSize]!)) ms at \(scaleSize) exceeds \(format(coldScaleFactor)) x the \(format(cold[budgetSize]!)) ms at \(budgetSize)"
        )
        if failed { exit(1) }
    }

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
                    set.status = .done
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

    private static func time(_ body: () -> Void) -> Double {
        let start = clock_gettime_nsec_np(CLOCK_THREAD_CPUTIME_ID)
        body()
        return Double(clock_gettime_nsec_np(CLOCK_THREAD_CPUTIME_ID) - start) / 1e6
    }

    private static func median(_ millis: [Double]) -> Double {
        millis.sorted()[millis.count / 2]
    }

    private static func format(_ millis: Double) -> String {
        millis.formatted(.number.precision(.fractionLength(2)))
    }
}
