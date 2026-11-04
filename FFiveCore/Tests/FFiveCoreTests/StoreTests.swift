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

    /// Two quick workouts that both hold Bench Press, oldest first, the way a later card finds an earlier pin.
    func benchTwice() -> (store: Store, first: Exercise, later: Exercise) {
        let store = Store(inMemory: true)
        let exercises = (0..<2).map { _ in
            let workout = store.startQuickWorkout()
            MesoPlanner.addExercise(named: "Bench Press", muscle: .chest, to: workout, unit: .lb, in: store.context)
            return workout.exercises[0]
        }
        return (store, exercises[0], exercises[1])
    }

    func pinned(_ store: Store, _ name: String) throws -> [String] {
        try store.context.fetch(FetchDescriptor<PinnedNote>(predicate: #Predicate { $0.name == name })).map(\.text)
    }

    func testSetNoteOnWorkoutTrimsAndBlankClears() {
        let store = Store(inMemory: true)
        let workout = store.startQuickWorkout()

        store.setNote("  Left shoulder tight \n", on: workout)
        XCTAssertEqual(workout.note, "Left shoulder tight", "the session header shows the trimmed note")
        XCTAssertFalse(store.context.hasChanges, "the note is saved")

        store.setNote("   ", on: workout)
        XCTAssertNil(workout.note, "a blank note removes the callout")
        XCTAssertNil(store.failure)
    }

    func testSetNoteOnExerciseStaysOnThatWorkout() throws {
        let (store, first, later) = benchTwice()

        store.setNote("  Elbows in \n", on: first)

        XCTAssertEqual(first.note, "Elbows in", "that workout's card shows the trimmed note")
        XCTAssertNil(later.note, "a later workout's card shows nothing")
        XCTAssertEqual(try pinned(store, "Bench Press"), [], "nothing is pinned")
        XCTAssertFalse(store.context.hasChanges, "the note is saved")
    }

    func testPinNoteCarriesToLaterWorkoutsAndEditsFollowThePin() throws {
        let (store, first, later) = benchTwice()
        store.setNote("Elbows in", on: first)

        store.pinNote(on: first)
        XCTAssertEqual(try pinned(store, "Bench Press"), ["Elbows in"], "every Bench Press card and the exercise page read the pin")
        XCTAssertNil(first.note, "the row copy is cleared so the note shows once")
        XCTAssertFalse(store.context.hasChanges, "the pin is saved")

        store.setNote("Seat Level: 5", on: later)
        XCTAssertEqual(try pinned(store, "Bench Press"), ["Seat Level: 5"], "editing from a later card edits the pin")
        XCTAssertNil(later.note, "the edit stays off the row")
        XCTAssertFalse(store.context.hasChanges, "the edit is saved")
    }

    func testUnpinNoteReturnsToThisWorkout() throws {
        let (store, first, later) = benchTwice()
        store.setNote("Seat Level: 5", on: first)
        store.pinNote(on: first)

        store.unpinNote(on: later)

        XCTAssertEqual(later.note, "Seat Level: 5", "the card that unpinned keeps the note")
        XCTAssertNil(first.note, "the workout that pinned it shows nothing")
        XCTAssertEqual(try pinned(store, "Bench Press"), [], "the exercise page no longer shows it")
        XCTAssertFalse(store.context.hasChanges, "the move is saved")
    }

    func testDeleteNoteRemovesThePinAndTheRow() throws {
        let (store, first, _) = benchTwice()
        store.setNote("Elbows in", on: first)
        store.pinNote(on: first)
        store.setNote("Seat Level: 5", on: first)

        store.deleteNote(on: first)

        XCTAssertNil(first.note, "the card shows no note")
        XCTAssertEqual(try pinned(store, "Bench Press"), [], "the exercise page shows no note")
        XCTAssertFalse(store.context.hasChanges, "the delete is saved")
        XCTAssertNil(store.failure)
    }
}
