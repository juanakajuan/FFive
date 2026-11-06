import XCTest

@testable import FFiveCore

@MainActor
final class SetImprovementTests: XCTestCase {
    func session(_ store: Store, _ sets: [(weight: Double, reps: Int, type: SetType)]) throws -> Exercise {
        let workout = store.startQuickWorkout()
        store.addExercise(named: "Bench Press", muscle: .chest, to: workout)
        let exercise = try XCTUnwrap(workout.exercises.first)
        while exercise.sets.count < sets.count { store.addSet(to: exercise) }
        for (set, entry) in zip(exercise.sortedSets, sets) {
            store.setType(entry.type, of: set)
            set.weight = entry.weight
            set.reps = entry.reps
            store.log(set, done: true)
        }
        return exercise
    }

    func testMarksSetsThatBeatTheSameWorkingSetLastSession() throws {
        let store = Store(inMemory: true)
        let last = try session(store, [(100, 8, .regular), (100, 8, .regular), (100, 8, .regular), (100, 8, .regular)])
        store.finish(try XCTUnwrap(last.workout))
        XCTAssertIdentical(store.lastFinishedExercise(last.key), last)

        let today = try session(
            store, [(100, 10, .regular), (105, 8, .regular), (100, 8, .regular), (110, 6, .regular)])
        let sets = today.sortedSets
        let improvements = today.improvements(over: store.lastFinishedExercise(today.key))

        XCTAssertEqual(improvements[ObjectIdentifier(sets[0])]?.addedReps, 2, "more reps at the same load beats")
        XCTAssertEqual(improvements[ObjectIdentifier(sets[1])]?.addedWeight, 5, "more load at the same reps beats")
        XCTAssertNil(improvements[ObjectIdentifier(sets[2])], "matching last time is not a beat")
        XCTAssertNil(improvements[ObjectIdentifier(sets[3])], "more load for fewer reps is not a clear beat")
    }

    func testMyorepsAreLeftOutBeforeMatching() throws {
        let store = Store(inMemory: true)
        let last = try session(store, [(100, 8, .regular)])
        store.finish(try XCTUnwrap(last.workout))

        let today = try session(store, [(60, 12, .myorep), (100, 9, .regular)])
        let improvements = today.improvements(over: store.lastFinishedExercise(today.key))

        XCTAssertNil(improvements[ObjectIdentifier(today.sortedSets[0])], "a myorep is never marked")
        XCTAssertEqual(improvements[ObjectIdentifier(today.sortedSets[1])]?.previous, LoggedSet(weight: 100, reps: 8))
    }

    func testNoLastSessionMarksNothing() throws {
        let store = Store(inMemory: true)
        let today = try session(store, [(100, 8, .regular)])
        XCTAssertTrue(today.improvements(over: store.lastFinishedExercise(today.key)).isEmpty)
    }
}
