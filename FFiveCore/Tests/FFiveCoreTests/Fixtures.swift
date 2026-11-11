import SwiftData
import XCTest

@testable import FFiveCore

extension MesoDraft {
    init(days: [Day]) {
        self.init(template: nil)
        self.days = days
    }

    /// Bench Press on day A and Barbell Row on day B.
    static var twoDay: MesoDraft {
        MesoDraft(days: [
            .init(name: "A", slots: [.init(exercise: "Bench Press", muscle: .chest)]),
            .init(name: "B", slots: [.init(exercise: "Barbell Row", muscle: .back)]),
        ])
    }
}

/// An in-memory store with `draft` started as its active block.
@MainActor
func startedStore(_ draft: MesoDraft = .twoDay) throws -> (Store, Mesocycle) {
    let store = Store(inMemory: true)
    try store.startMesocycle(draft)
    return (store, try XCTUnwrap(store.context.fetch(Mesocycle.active).first))
}

extension Store {
    /// Fills an empty set with a lift, since a set without reps and weight cannot be logged.
    func logEntered(_ set: SetEntry) {
        if set.weight == 0 { set.weight = 100 }
        if set.reps == 0 { set.reps = 8 }
        log(set, done: true)
    }

    /// Logs every set of `workout` at one lift and finishes it.
    func finishAll(_ workout: Workout, weight: Double = 100, reps: Int = 8, startedAt start: Date? = nil) {
        for set in workout.sortedExercises.flatMap(\.sortedSets) {
            set.weight = weight
            set.reps = reps
            log(set, done: true)
        }
        if let start { workout.startDate = start }
        finish(workout)
    }

    /// Builds the session at `key` and finishes it with every set logged at one lift.
    @discardableResult
    func finish(_ key: SessionKey, of meso: Mesocycle, weight: Double = 100, reps: Int = 8) -> Workout {
        let workout = buildSession(meso, at: key)
        finishAll(workout, weight: weight, reps: reps)
        return workout
    }
}
