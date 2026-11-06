import XCTest

@testable import FFiveCore

@MainActor
final class SetComparisonTests: XCTestCase {
    typealias Entry = (weight: Double, reps: Int, type: SetType)

    func session(_ store: Store, _ sets: [Entry], targets: [SetTarget] = []) throws -> Exercise {
        let workout = store.startQuickWorkout()
        store.addExercise(named: "Bench Press", muscle: .chest, to: workout)
        let exercise = try XCTUnwrap(workout.exercises.first)
        while exercise.sets.count < sets.count { store.addSet(to: exercise) }
        for (index, (set, entry)) in zip(exercise.sortedSets, sets).enumerated() {
            set.targetWeight = index < targets.count ? targets[index].weight : nil
            set.targetReps = index < targets.count ? targets[index].reps : nil
            store.setType(entry.type, of: set)
            set.weight = entry.weight
            set.reps = entry.reps
            store.log(set, done: true)
        }
        return exercise
    }

    func outcomes(_ exercise: Exercise, _ comparisons: [ObjectIdentifier: SetComparison]) -> [SetComparison.Outcome?] {
        exercise.sortedSets.map { comparisons[ObjectIdentifier($0)]?.outcome }
    }

    func testJudgesASetAgainstItsTargetAtTheLoadLifted() throws {
        let store = Store(inMemory: true)
        let target = SetTarget(weight: 185, reps: 7)
        let today = try session(
            store,
            [(185, 6, .regular), (185, 7, .regular), (185, 8, .regular), (190, 6, .regular), (175, 7, .regular)],
            targets: Array(repeating: target, count: 5))
        let comparisons = today.comparisons(with: nil)

        XCTAssertEqual(
            outcomes(today, comparisons), [.below, .met, .above, .met, .below],
            "a heavier load expects fewer reps and a lighter one more")
        let heavier = try XCTUnwrap(comparisons[ObjectIdentifier(today.sortedSets[3])])
        XCTAssertEqual(heavier.basis, .target)
        XCTAssertEqual(heavier.expected, LoggedSet(weight: 185, reps: 7))
        XCTAssertEqual(heavier.expectedReps, 6)
    }

    func testWithoutATargetJudgesAgainstTheSameSetLastSession() throws {
        let store = Store(inMemory: true)
        let last = try session(store, Array(repeating: (100, 8, .regular), count: 3))
        store.finish(try XCTUnwrap(last.workout))

        let today = try session(
            store, [(100, 9, .regular), (100, 8, .regular), (100, 7, .regular), (100, 8, .regular)])
        let comparisons = today.comparisons(with: store.lastFinishedExercise(today.key))

        XCTAssertEqual(
            outcomes(today, comparisons), [.above, .met, .below, nil],
            "a set past last session's count has nothing to meet")
        XCTAssertEqual(comparisons[ObjectIdentifier(today.sortedSets[0])]?.basis, .lastSession)
    }

    func testMyorepsAreLeftOutBeforeMatching() throws {
        let store = Store(inMemory: true)
        let last = try session(store, [(100, 8, .regular)])
        store.finish(try XCTUnwrap(last.workout))

        let today = try session(store, [(60, 12, .myorep), (100, 9, .regular)])
        let comparisons = today.comparisons(with: store.lastFinishedExercise(today.key))

        XCTAssertEqual(
            outcomes(today, comparisons), [nil, .above], "a myorep is never judged and does not shift matching")
    }

    func testNothingToMeetJudgesNothing() throws {
        let store = Store(inMemory: true)
        let today = try session(store, [(100, 8, .regular)])
        XCTAssertTrue(today.comparisons(with: store.lastFinishedExercise(today.key)).isEmpty)
    }
}
