import SwiftData
import XCTest

@testable import FFiveCore

@MainActor
final class ExerciseHistoryTests: XCTestCase {
    func draft() -> MesoDraft {
        var draft = MesoDraft(template: nil)
        draft.days = [.init(name: "Push", slots: [.init(exercise: "Bench Press", muscle: .chest)])]
        return draft
    }

    func logAll(_ workout: Workout, _ store: Store, at start: Date) {
        for set in workout.exercises.flatMap(\.sortedSets) {
            set.weight = 100
            set.reps = 8
            store.log(set, done: true)
        }
        workout.startDate = start
        store.finish(workout)
    }

    func testListsEveryFinishedSessionNewestFirstGroupedByMeso() throws {
        let store = Store(inMemory: true)
        let t0 = Date(timeIntervalSince1970: 1_800_000_000)
        let day = 86_400.0

        try store.startMesocycle(draft())
        let first = try XCTUnwrap(store.context.fetch(Mesocycle.active).first)
        logAll(store.buildSession(first, at: SessionKey(week: 0, dayIndex: 0)), store, at: t0)
        logAll(store.buildSession(first, at: SessionKey(week: 1, dayIndex: 0)), store, at: t0 + 7 * day)
        store.endMesocycle(first)

        let quick = store.startQuickWorkout()
        store.addExercise(named: "bench press", muscle: .chest, to: quick)
        logAll(quick, store, at: t0 + 10 * day)

        try store.startMesocycle(draft())
        let second = try XCTUnwrap(store.context.fetch(Mesocycle.active).first)
        logAll(store.buildSession(second, at: SessionKey(week: 0, dayIndex: 0)), store, at: t0 + 14 * day)
        store.buildSession(second, at: SessionKey(week: 1, dayIndex: 0))

        let skipped = store.startQuickWorkout()
        store.addExercise(named: "Bench Press", muscle: .chest, to: skipped)
        skipped.startDate = t0 + 20 * day
        store.finish(skipped)

        let groups = store.exerciseHistory(ExerciseID(folding: "Bench Press"))
        XCTAssertEqual(groups.count, 3, "the second meso, the quick workout, then the first meso")
        XCTAssertTrue(groups[0].mesocycle === second)
        XCTAssertNil(groups[1].mesocycle, "a quick workout has no meso")
        XCTAssertTrue(groups[2].mesocycle === first)
        XCTAssertEqual(
            groups.map(\.sessions.count), [1, 1, 2], "open sessions and ones with no logged set are left out")
        XCTAssertEqual(groups[2].sessions.compactMap(\.workout?.week), [1, 0], "newest first inside a meso")
        XCTAssertEqual(
            store.lastPerformed()[ExerciseID(folding: "Bench Press")], t0 + 14 * day,
            "the newest finished session with a logged set, not the open or empty ones")
        XCTAssertNil(store.lastPerformed()[ExerciseID(folding: "Squat")], "an exercise never done has no date")
    }

    func testPerformedOnlyKeepsExercisesWithALoggedSetInAFinishedWorkout() {
        let store = Store(inMemory: true)
        let names = { (performedOnly: Bool) in
            store.library(muscle: nil, equipment: nil, search: "", performedOnly: performedOnly).map(\.name)
        }
        XCTAssertEqual(names(true), [], "nothing logged yet")
        XCTAssertEqual(names(false).count, store.library(muscle: nil, equipment: nil, search: "").count)

        let done = store.startQuickWorkout()
        store.addExercise(named: "Bench Press", muscle: .chest, to: done)
        store.addExercise(named: "Squat", muscle: .quads, to: done)
        let benchSets = done.exercises.first { $0.key == ExerciseID(folding: "Bench Press") }?.sortedSets ?? []
        for set in benchSets {
            set.weight = 100
            set.reps = 8
            store.log(set, done: true)
        }
        store.finish(done)

        let open = store.startQuickWorkout()
        store.addExercise(named: "Deadlift", muscle: .hamstrings, to: open)
        for set in open.exercises.flatMap(\.sortedSets) {
            set.weight = 100
            set.reps = 5
            store.log(set, done: true)
        }

        XCTAssertEqual(
            names(true), ["Bench Press"],
            "an exercise with no logged set, or logged only in an open workout, is left out")
        XCTAssertEqual(
            store.library(muscle: .quads, equipment: nil, search: "", performedOnly: true).map(\.name), [],
            "it combines with the other filters")
    }

    func testRenamingACustomExerciseMovesItsLastPerformedDate() throws {
        let store = Store(inMemory: true)
        let workout = store.startQuickWorkout()
        store.addExercise(named: "Sled Drag", muscle: .quads, to: workout)
        logAll(workout, store, at: Date(timeIntervalSince1970: 1_700_000_000))
        let old = ExerciseID(folding: "Sled Drag")
        XCTAssertEqual(store.lastPerformed()[old], workout.startDate)

        let custom = try XCTUnwrap(store.customExercise(old))
        var draft = CustomExerciseDraft(custom)
        draft.name = "Sled Pull"
        try store.saveCustomExercise(draft, editing: custom)

        XCTAssertNil(store.lastPerformed()[old], "the old name is gone")
        XCTAssertEqual(store.lastPerformed()[ExerciseID(folding: "Sled Pull")], workout.startDate)
        XCTAssertEqual(
            store.library(muscle: nil, equipment: nil, search: "", performedOnly: true).map(\.name), ["Sled Pull"])
    }

    func testBestSetIsTheStrongestSetElseTheHeaviest() throws {
        let store = Store(inMemory: true)
        let workout = store.startQuickWorkout()
        store.addExercise(named: "Bench Press", muscle: .chest, to: workout)
        let bench = try XCTUnwrap(workout.exercises.first)
        while bench.sets.count < 2 { store.addSet(to: bench) }
        let sets = bench.sortedSets
        let (heavy, strong) = (sets[0], sets[1])
        for (set, weight, reps) in [(heavy, 100.0, 3), (strong, 90.0, 10)] {
            set.weight = weight
            set.reps = reps
            store.log(set, done: true)
        }

        XCTAssertIdentical(bench.bestSet, strong, "90 × 10 estimates a higher 1RM than 100 × 3")

        for set in [heavy, strong] { store.setType(.myorep, of: set) }
        XCTAssertIdentical(bench.bestSet, heavy, "with no strength estimate, the heaviest done set stands in")
    }
}
