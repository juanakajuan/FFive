import XCTest

@testable import FFiveCore

@MainActor
final class SetComparisonTests: XCTestCase {
    typealias Entry = (weight: Double, reps: Int, type: SetType)

    func session(_ store: Store, _ sets: [Entry]) throws -> Exercise {
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

    func finished(_ store: Store, _ sets: [Entry]) throws {
        store.finish(try XCTUnwrap(try session(store, sets).workout))
    }

    func outcomes(_ exercise: Exercise, _ comparisons: [ObjectIdentifier: SetComparison]) -> [SetComparison.Outcome?] {
        exercise.sortedSets.map { comparisons[ObjectIdentifier($0)]?.outcome }
    }

    func testJudgesEachSetAgainstTheSameSetLastSessionAtTheLoadLifted() throws {
        let store = Store(inMemory: true)
        try finished(store, Array(repeating: (185, 7, .regular), count: 6))

        let today = try session(
            store,
            [
                (185, 8, .regular), (185, 7, .regular), (185, 6, .regular), (190, 6, .regular), (195, 6, .regular),
                (175, 7, .regular),
            ])
        let comparisons = today.comparisons(with: store.lastFinishedExercise(today.key))

        XCTAssertEqual(
            outcomes(today, comparisons), [.improved, .maintained, .regressed, .maintained, .improved, .regressed],
            "a heavier load expects fewer reps and a lighter one more")
        let heavier = try XCTUnwrap(comparisons[ObjectIdentifier(today.sortedSets[4])])
        XCTAssertEqual(heavier.previous, LoggedSet(weight: 185, reps: 7))
        XCTAssertEqual(heavier.expectedReps, 5)
    }

    func testASetPastLastSessionsCountIsNotJudged() throws {
        let store = Store(inMemory: true)
        try finished(store, [(100, 8, .regular)])
        let today = try session(store, [(100, 8, .regular), (100, 8, .regular)])
        let comparisons = today.comparisons(with: store.lastFinishedExercise(today.key))
        XCTAssertEqual(outcomes(today, comparisons), [.maintained, nil])
    }

    func testMyorepsAreLeftOutBeforeMatching() throws {
        let store = Store(inMemory: true)
        try finished(store, [(100, 8, .regular)])
        let today = try session(store, [(60, 12, .myorep), (100, 9, .regular)])
        let comparisons = today.comparisons(with: store.lastFinishedExercise(today.key))
        XCTAssertEqual(
            outcomes(today, comparisons), [nil, .improved], "a myorep is never judged and does not shift matching")
    }

    func testNoLastSessionJudgesNothing() throws {
        let store = Store(inMemory: true)
        let today = try session(store, [(100, 8, .regular)])
        XCTAssertTrue(today.comparisons(with: store.lastFinishedExercise(today.key)).isEmpty)
    }

    func testFinishingAWorkoutMakesItTheLastSessionAfterAnEarlierRead() throws {
        let store = Store(inMemory: true)
        try finished(store, [(100, 8, .regular)])
        let today = try session(store, [(105, 8, .regular)])
        let first = try XCTUnwrap(store.lastFinishedExercise(today.key))
        XCTAssertNotEqual(first.workout, today.workout)

        store.finish(try XCTUnwrap(today.workout))

        XCTAssertEqual(
            store.lastFinishedExercise(today.key)?.workout, today.workout,
            "a finished workout replaces the one read before it")
    }
}
