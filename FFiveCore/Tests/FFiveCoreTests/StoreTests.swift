import SwiftData
import XCTest
@testable import FFiveCore

@MainActor
final class StoreTests: XCTestCase {
    let day1 = SessionKey(week: 0, dayIndex: 0)
    let day2 = SessionKey(week: 0, dayIndex: 1)

    func twoDayDraft() -> MesoDraft {
        var draft = MesoDraft(template: nil)
        draft.days = [.init(name: "A", slots: [.init(exercise: "Bench Press", muscle: .chest)]),
                      .init(name: "B", slots: [.init(exercise: "Barbell Row", muscle: .back)])]
        return draft
    }

    func startedStore() throws -> (Store, Mesocycle) {
        let store = Store(inMemory: true)
        try store.startMesocycle(twoDayDraft())
        return (store, try XCTUnwrap(store.context.fetch(Mesocycle.active).first))
    }

    func testEndWithOpenLoggedSessionKeepsItInHistory() throws {
        let (store, meso) = try startedStore()
        let started = store.buildSession(meso, at: day1, unit: .lb)
        started.sortedExercises[0].sortedSets[0].isDone = true
        store.buildSession(meso, at: day2, unit: .lb)

        store.endMesocycle(meso)

        let history = try store.context.fetch(Workout.history)
        XCTAssertEqual(history.map(\.name), ["A"], "the session with a logged set reaches history")
        XCTAssertEqual(history.first?.completedSets, 1, "its logged set is kept")
        XCTAssertNotNil(history.first?.endDate)
        XCTAssertTrue(try store.context.fetch(Workout.open).isEmpty, "the untouched day leaves no open session behind")
        XCTAssertTrue(try store.context.fetch(Mesocycle.active).isEmpty, "the block is ended")
        XCTAssertNil(store.failure)
    }

    func testSecondStartIsRefused() throws {
        let (store, _) = try startedStore()

        XCTAssertThrowsError(try store.startMesocycle(twoDayDraft())) { error in
            XCTAssertEqual(error as? StoreError, .anotherMesocycleIsActive)
        }
        XCTAssertEqual(try store.context.fetchCount(FetchDescriptor<Mesocycle>()), 1, "the refused start inserts nothing")
    }

    func testDeleteWorkoutDetachesFromBlock() throws {
        let (store, meso) = try startedStore()
        let workout = store.buildSession(meso, at: day1, unit: .lb)
        workout.sortedExercises[0].sortedSets[0].isDone = true
        store.finish(workout)
        XCTAssertEqual(try store.context.fetch(Workout.history).count, 1)

        store.delete(workout)

        XCTAssertTrue(try store.context.fetch(Workout.history).isEmpty, "the workout leaves history")
        XCTAssertNil(meso.workout(at: day1), "the block no longer lists it")
        XCTAssertEqual(meso.status(at: day1), .upcoming, "its day is open to train again")
        XCTAssertEqual(meso.nextUp, day1)
    }
}
