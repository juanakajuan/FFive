import SwiftData
import XCTest

@testable import FFiveCore

@MainActor
final class MesoLengthTests: XCTestCase {
    func startedStore() throws -> (Store, Mesocycle) {
        let store = Store(inMemory: true)
        var draft = MesoDraft(template: nil)
        draft.days = [
            .init(name: "A", slots: [.init(exercise: "Bench Press", muscle: .chest)]),
            .init(name: "B", slots: [.init(exercise: "Barbell Row", muscle: .back)]),
        ]
        try store.startMesocycle(draft)
        return (store, try XCTUnwrap(store.context.fetch(Mesocycle.active).first))
    }

    func finish(_ key: SessionKey, of meso: Mesocycle, in store: Store) {
        let workout = store.buildSession(meso, at: key)
        for set in workout.sortedExercises.flatMap(\.sortedSets) { store.logEntered(set) }
        store.finish(workout)
    }

    func testAddingAWeekMovesTheDeloadAndEveryWeeksRIR() throws {
        let (store, meso) = try startedStore()
        XCTAssertEqual((0..<meso.totalWeeks).map { meso.phase(week: $0).rir }, [3, 2, 1, 0, nil])

        store.changeLength(of: meso, by: 1)

        XCTAssertEqual(meso.accumulationWeeks, 5)
        XCTAssertEqual((0..<meso.totalWeeks).map { meso.phase(week: $0).rir }, [3, 3, 2, 1, 0, nil])
        XCTAssertEqual(meso.allKeys.count, 12, "the block gains a week of both days")
        XCTAssertFalse(store.context.hasChanges, "the change is saved")
    }

    func testRemovingAWeekMovesTheDeloadAndEveryWeeksRIR() throws {
        let (store, meso) = try startedStore()

        store.changeLength(of: meso, by: -1)

        XCTAssertEqual((0..<meso.totalWeeks).map { meso.phase(week: $0).rir }, [2, 1, 0, nil])
    }

    func testLengthStaysInsideTheBuilderRange() throws {
        let (store, meso) = try startedStore()
        store.changeLength(of: meso, by: -1)
        XCTAssertFalse(meso.canRemoveWeek, "a block keeps at least 3 accumulation weeks")
        store.changeLength(of: meso, by: -1)
        XCTAssertEqual(meso.accumulationWeeks, 3)

        for _ in 0..<5 { store.changeLength(of: meso, by: 1) }
        XCTAssertEqual(meso.accumulationWeeks, 6, "a block has at most 6 accumulation weeks")
        XCTAssertFalse(meso.canAddWeek)
    }

    func testRemovingAWeekWithLoggedSetsIsRefused() throws {
        let (store, meso) = try startedStore()
        for week in 0..<3 {
            for day in 0..<2 { finish(SessionKey(week: week, dayIndex: day), of: meso, in: store) }
        }
        let lastWeek = store.buildSession(meso, at: SessionKey(week: 3, dayIndex: 0))
        XCTAssertTrue(meso.canRemoveWeek, "a built but unlogged last week can still go")

        store.logEntered(lastWeek.sortedExercises[0].sortedSets[0])

        XCTAssertFalse(meso.canRemoveWeek, "the last accumulation week has a logged set")
        store.changeLength(of: meso, by: -1)
        XCTAssertEqual(meso.accumulationWeeks, 4, "the refused change leaves the block as it was")
        XCTAssertTrue(meso.canAddWeek, "a week can still be added before the deload")
    }

    func testAddingAWeekIsRefusedOnceTheDeloadIsLogged() throws {
        let (store, meso) = try startedStore()
        let deload = store.buildSession(meso, at: SessionKey(week: 4, dayIndex: 0))
        store.logEntered(deload.sortedExercises[0].sortedSets[0])

        XCTAssertFalse(meso.canAddWeek)
        XCTAssertFalse(meso.canRemoveWeek)
        store.changeLength(of: meso, by: 1)
        XCTAssertEqual(meso.accumulationWeeks, 4)
    }

    func testLoggedSessionsKeepTheRIRTheyWereTrainedAt() throws {
        let (store, meso) = try startedStore()
        finish(SessionKey(week: 0, dayIndex: 0), of: meso, in: store)
        finish(SessionKey(week: 1, dayIndex: 0), of: meso, in: store)
        let trained = try XCTUnwrap(meso.workout(at: SessionKey(week: 1, dayIndex: 0)))
        let targets = trained.sortedExercises[0].sortedSets.map {
            SetTarget(weight: $0.targetWeight, reps: $0.targetReps)
        }

        store.changeLength(of: meso, by: 1)

        XCTAssertEqual(trained.phase?.rir, 2, "week 2 was trained at 2 RIR and still reads so")
        XCTAssertEqual(meso.phase(week: 1).rir, 3, "the block's week 2 now aims at 3 RIR")
        XCTAssertTrue(meso.workout(at: SessionKey(week: 1, dayIndex: 0)) === trained, "a logged session is kept")
        XCTAssertEqual(
            trained.sortedExercises[0].sortedSets.map { SetTarget(weight: $0.targetWeight, reps: $0.targetReps) },
            targets, "its sets are untouched")
    }

    func testUnloggedSessionsOfChangedWeeksAreRebuilt() throws {
        let (store, meso) = try startedStore()
        finish(SessionKey(week: 0, dayIndex: 0), of: meso, in: store)
        let week2 = SessionKey(week: 1, dayIndex: 0)
        let built = store.buildSession(meso, at: week2)
        let oldReps = built.sortedExercises[0].sortedSets.map(\.targetReps)

        store.changeLength(of: meso, by: 1)

        let rebuilt = try XCTUnwrap(meso.workout(at: week2))
        XCTAssertTrue(rebuilt === built, "the session is rebuilt in place, so a screen showing it stays put")
        XCTAssertEqual(meso.workouts.filter { $0.key == week2 }.count, 1)
        XCTAssertEqual(rebuilt.phase?.rir, 3)
        let newReps = rebuilt.sortedExercises[0].sortedSets.map(\.targetReps)
        XCTAssertEqual(
            zip(oldReps, newReps).map { ($0 ?? 0) - ($1 ?? 0) }, Array(repeating: 1, count: newReps.count),
            "aiming at 3 RIR instead of 2 asks for one rep fewer")
    }

    func testUnloggedSessionsOfUnchangedWeeksAreKept() throws {
        let (store, meso) = try startedStore()
        let first = store.buildSession(meso, at: SessionKey(week: 0, dayIndex: 0))

        store.changeLength(of: meso, by: 1)

        XCTAssertTrue(meso.workout(at: SessionKey(week: 0, dayIndex: 0)) === first, "week 1 stays at 3 RIR")
    }

    func testRemovingAWeekDropsTheOldDeloadSession() throws {
        let (store, meso) = try startedStore()
        store.buildSession(meso, at: SessionKey(week: 4, dayIndex: 1))
        store.skip(SessionKey(week: 4, dayIndex: 0), of: meso)
        store.skip(SessionKey(week: 3, dayIndex: 0), of: meso)
        store.skip(SessionKey(week: 2, dayIndex: 0), of: meso)

        store.changeLength(of: meso, by: -1)

        XCTAssertTrue(meso.workouts.isEmpty, "the old deload week is gone")
        XCTAssertEqual(meso.status(at: SessionKey(week: 3, dayIndex: 0)), .upcoming, "the new deload starts unskipped")
        XCTAssertEqual(meso.status(at: SessionKey(week: 2, dayIndex: 0)), .skipped, "a skip of a kept week stays")
        XCTAssertNil(store.failure)
    }
}
