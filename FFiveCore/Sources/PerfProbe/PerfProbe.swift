import Foundation
import SwiftData

@testable import FFiveCore

@main
struct PerfProbe {
    static let budgetSize = 156
    static let scaleSize = 468
    static let sizes = [0, budgetSize, scaleSize]
    static let budgetMillis = 20.0
    static let pickerBudgetMillis = 1.0
    static let cardBudgetMillis = 0.5
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

        var pickerColds: [Int: [Double]] = [:]
        var pickerWarms: [Int: [Double]] = [:]
        var pickerListed: [Int: Int] = [:]
        for _ in 0..<rounds {
            for size in sizes {
                let (store, _) = stores[size]!
                store.commit()
                pickerColds[size, default: []].append(time { pickerListed[size] = pickerRender(store) })
                for _ in 0..<warmPerRound {
                    pickerWarms[size, default: []].append(time { pickerListed[size] = pickerRender(store) })
                }
            }
        }
        for size in sizes {
            print(
                "perf-probe: exercise picker median \(format(median(pickerWarms[size]!))) ms (min \(format(pickerWarms[size]!.min()!))) at \(size) finished workouts, \(format(median(pickerColds[size]!))) ms (min \(format(pickerColds[size]!.min()!))) on the first render after a commit"
            )
        }

        var cardColds: [Int: [Double]] = [:]
        var cardWarms: [Int: [Double]] = [:]
        var cardCompared: [Int: Int] = [:]
        for _ in 0..<rounds {
            for size in sizes {
                let (store, meso) = stores[size]!
                let session = store.buildSession(meso, at: SessionKey(week: 0, dayIndex: 0))
                store.commit()
                cardColds[size, default: []].append(time { cardCompared[size] = cardsRender(store, session) })
                for _ in 0..<warmPerRound {
                    cardWarms[size, default: []].append(time { cardCompared[size] = cardsRender(store, session) })
                }
            }
        }
        for size in sizes {
            print(
                "perf-probe: exercise cards median \(format(median(cardWarms[size]!))) ms (min \(format(cardWarms[size]!.min()!))) at \(size) finished workouts, \(format(median(cardColds[size]!))) ms (min \(format(cardColds[size]!.min()!))) on the first render after a commit"
            )
        }

        let (store, meso) = stores[budgetSize]!
        var strength: [Double] = []
        var progressWarm: [Double] = []
        var progressSeries = 0
        for _ in 0..<rounds {
            store.commit()
            strength.append(time { _ = store.strengthSeries() })
            for _ in 0..<warmPerRound {
                progressWarm.append(time { progressSeries = progressRender(store) })
            }
        }
        print(
            "perf-probe: strengthSeries median \(format(median(strength))) ms (min \(format(strength.min()!))) at \(budgetSize) finished workouts over \(rounds) reads, each after a commit"
        )
        print(
            "perf-probe: progress screen median \(format(median(progressWarm))) ms (min \(format(progressWarm.min()!))) per render between commits at \(budgetSize) finished workouts (strengthSeries and weekStats)"
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
        let pickerWarm = pickerWarms.mapValues { $0.min()! }
        gate(
            pickerListed[scaleSize] == lifts.count,
            "exercise picker listed \(pickerListed[scaleSize]!) performed exercises at \(scaleSize), not the \(lifts.count) seeded, so the probe timed the wrong work"
        )
        gate(
            pickerWarm[scaleSize]! <= pickerBudgetMillis,
            "exercise picker min \(format(pickerWarm[scaleSize]!)) ms at \(scaleSize) exceeds \(format(pickerBudgetMillis)) ms, so a keystroke scans the workout history"
        )
        let cardWarm = cardWarms.mapValues { $0.min()! }
        gate(
            cardCompared[scaleSize] == lifts.count,
            "exercise cards found \(cardCompared[scaleSize]!) last finished exercises at \(scaleSize), not the \(lifts.count) seeded, so the probe timed the wrong work"
        )
        gate(
            cardWarm[scaleSize]! <= cardBudgetMillis,
            "exercise cards min \(format(cardWarm[scaleSize]!)) ms at \(scaleSize) exceeds \(format(cardBudgetMillis)) ms, so a keystroke in a set field fetches the workout history"
        )
        gate(
            progressSeries == lifts.count,
            "progress screen found \(progressSeries) strength series at \(budgetSize), not the \(lifts.count) seeded, so the probe timed the wrong work"
        )
        gate(
            progressWarm.min()! <= cardBudgetMillis,
            "progress screen min \(format(progressWarm.min()!)) ms at \(budgetSize) exceeds \(format(cardBudgetMillis)) ms, so a render between commits rescans the workout history"
        )
        if failed { exit(1) }
    }

    /// What one body pass of the exercise picker asks the store for, with "Only exercises I've performed" on.
    /// Returns how many exercises it listed.
    @MainActor
    private static func pickerRender(_ store: Store) -> Int {
        _ = store.lastPerformed()
        return store.library(muscle: nil, equipment: nil, search: "", performedOnly: true).count
    }

    /// What one body pass of the Progress screen asks the store for, Strength and History panes together.
    /// Returns how many strength series it found.
    @MainActor
    private static func progressRender(_ store: Store) -> Int {
        _ = store.weekStats()
        return store.strengthSeries().count
    }

    /// What one body pass of every exercise card in a session asks the store for.
    /// Returns how many cards found a last finished exercise.
    @MainActor
    private static func cardsRender(_ store: Store, _ session: Workout) -> Int {
        session.sortedExercises.filter { exercise in
            let previous = store.lastFinishedExercise(exercise.key)
            _ = exercise.comparisons(with: previous)
            return previous != nil
        }.count
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
