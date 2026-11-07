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
}
