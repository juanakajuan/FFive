import SwiftData
import XCTest

@testable import FFiveCore

@MainActor
final class StoreTests: XCTestCase {
    let day1 = SessionKey(week: 0, dayIndex: 0)
    let day2 = SessionKey(week: 0, dayIndex: 1)

    func twoDayDraft() -> MesoDraft {
        var draft = MesoDraft(template: nil)
        draft.days = [
            .init(name: "A", slots: [.init(exercise: "Bench Press", muscle: .chest)]),
            .init(name: "B", slots: [.init(exercise: "Barbell Row", muscle: .back)]),
        ]
        return draft
    }

    func startedStore() throws -> (Store, Mesocycle) {
        let store = Store(inMemory: true)
        try store.startMesocycle(twoDayDraft())
        return (store, try XCTUnwrap(store.context.fetch(Mesocycle.active).first))
    }

    func testEndWithOpenLoggedSessionKeepsItInHistory() throws {
        let (store, meso) = try startedStore()
        let started = store.buildSession(meso, at: day1)
        store.log(started.sortedExercises[0].sortedSets[0], done: true)
        store.buildSession(meso, at: day2)

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
        XCTAssertEqual(
            try store.context.fetchCount(FetchDescriptor<Mesocycle>()), 1, "the refused start inserts nothing")
    }

    func testDeleteWorkoutDetachesFromBlock() throws {
        let (store, meso) = try startedStore()
        let workout = store.buildSession(meso, at: day1)
        store.log(workout.sortedExercises[0].sortedSets[0], done: true)
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
            store.addExercise(named: "Bench Press", muscle: .chest, to: workout)
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
        XCTAssertEqual(
            try pinned(store, "Bench Press"), ["Elbows in"], "every Bench Press card and the exercise page read the pin"
        )
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

    func finishedBench(_ store: Store) {
        let workout = store.startQuickWorkout()
        store.addExercise(named: "Bench Press", muscle: .chest, to: workout)
        store.addSet(to: workout.exercises[0])
        for set in workout.exercises[0].sets {
            set.weight = 100
            set.reps = 8
            store.log(set, done: true)
        }
        store.finish(workout)
    }

    func testLogSetRestartsUntouchedClock() throws {
        let (store, meso) = try startedStore()
        let workout = store.buildSession(meso, at: day1)
        let sets = workout.sortedExercises[0].sortedSets
        let shown = Date.now - 600
        workout.startDate = shown

        store.log(sets[0], done: true)
        XCTAssertGreaterThan(workout.startDate, shown + 590, "the first logged set starts the session clock")
        XCTAssertTrue(sets[0].isDone)
        XCTAssertFalse(store.context.hasChanges, "the log is saved")

        let started = workout.startDate
        store.log(sets[1], done: true)
        XCTAssertEqual(workout.startDate, started, "later sets leave the clock alone")
        store.log(sets[0], done: false)
        XCTAssertFalse(sets[0].isDone, "a set can be unlogged")
        XCTAssertEqual(workout.startDate, started, "unlogging does not touch the clock")

        let quick = store.startQuickWorkout()
        store.addExercise(named: "Squat", muscle: .quads, to: quick)
        let quickStart = quick.startDate
        store.log(quick.exercises[0].sets[0], done: true)
        XCTAssertEqual(quick.startDate, quickStart, "a quick workout's timer runs from when it was started")
        XCTAssertNil(store.failure)
    }

    func testAddExerciseUsesPlannerInBlockAndPrefillInQuick() throws {
        let store = Store(inMemory: true)
        finishedBench(store)
        try store.startMesocycle(twoDayDraft())
        let meso = try XCTUnwrap(store.context.fetch(Mesocycle.active).first)
        let session = store.buildSession(meso, at: day2)

        store.addExercise(named: "Bench Press", muscle: .chest, to: session)
        let planned = try XCTUnwrap(session.sortedExercises.last)
        XCTAssertEqual(planned.name, "Bench Press")
        XCTAssertGreaterThanOrEqual(planned.sets.count, 2, "a block prescribes a first-week set count for the muscle")
        for set in planned.sets {
            XCTAssertNotNil(set.targetWeight, "the planner sets a load from the lifter's history")
            XCTAssertEqual(set.weight, set.targetWeight, "the row prefills with its target")
            XCTAssertFalse(set.isDone)
        }
        XCTAssertNotEqual(planned.sets.map(\.weight), [100, 100], "a block does not copy last time's sets")

        let quick = store.startQuickWorkout()
        store.addExercise(named: "Bench Press", muscle: .chest, to: quick)
        let prefilled = try XCTUnwrap(quick.sortedExercises.last)
        XCTAssertEqual(
            prefilled.sortedSets.map { ($0.weight, $0.reps) }.map { "\($0.0)x\($0.1)" }, ["100.0x8", "100.0x8"],
            "a quick workout prefills last time's done sets")
        XCTAssertTrue(prefilled.sets.allSatisfy { $0.targetWeight == nil && !$0.isDone })

        store.addExercise(named: "Face Pull", muscle: .rearDelts, to: quick)
        let fresh = try XCTUnwrap(quick.sortedExercises.last)
        XCTAssertEqual(
            fresh.sortedSets.map { ($0.weight, $0.reps) }.map { "\($0.0)x\($0.1)" }, ["0.0x10"],
            "an exercise never done before gets one empty set")
        XCTAssertFalse(store.context.hasChanges, "every add is saved")
    }

    func benchTarget(_ store: Store, _ meso: Mesocycle) throws -> SetTarget {
        let oneRepMax = Progression.estimatedOneRepMax(weight: 100, reps: 8)
        let key = ExerciseID(folding: "Bench Press")
        let reps = Progression.startingReps(in: ExerciseCatalog.repRange(for: key))
        let rir = try XCTUnwrap(meso.phase(week: 0).rir)
        let load = Progression.load(
            forReps: reps, rir: rir, oneRepMax: oneRepMax,
            increment: ExerciseCatalog.increment(for: key, unit: store.settings.weightUnit))
        XCTAssertNotEqual(SetTarget(weight: load, reps: reps), SetTarget.calibrate)
        return SetTarget(weight: load, reps: reps)
    }

    func testSnapshotRefreshesAfterACommit() throws {
        let (store, meso) = try startedStore()
        XCTAssertGreaterThan(store.weeklyVolume(meso, week: 0).count, 0)

        finishedBench(store)
        let session = store.buildSession(meso, at: day1)

        let targets = session.sortedExercises[0].sortedSets.map(\.target)
        XCTAssertFalse(targets.isEmpty)
        XCTAssertEqual(
            targets, Array(repeating: try benchTarget(store, meso), count: targets.count),
            "a workout finished after a render feeds the next build")
    }

    func testSnapshotRefreshesAfterAFailedSave() throws {
        if #unavailable(macOS 27) {
            throw XCTSkip("SwiftData before macOS 27 traps resolving a row whose save failed (ModelContext.swift:3256)")
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("nosave-\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: url) }
        try Store(
            container: ModelContainer(
                for: AppStore.schema, configurations: ModelConfiguration(schema: AppStore.schema, url: url)),
            settings: Settings()
        ).startMesocycle(twoDayDraft())
        let readOnly = ModelConfiguration(schema: AppStore.schema, url: url, allowsSave: false)
        let store = Store(
            container: try ModelContainer(for: AppStore.schema, configurations: readOnly), settings: Settings())
        let meso = try XCTUnwrap(store.context.fetch(Mesocycle.active).first)
        XCTAssertGreaterThan(store.weeklyVolume(meso, week: 0).count, 0)

        finishedBench(store)
        XCTAssertNotNil(store.failure, "a store that cannot save fails every commit")
        let session = store.buildSession(meso, at: day1)

        let targets = session.sortedExercises[0].sortedSets.map(\.target)
        XCTAssertFalse(targets.isEmpty)
        XCTAssertEqual(
            targets, Array(repeating: try benchTarget(store, meso), count: targets.count),
            "a workout the context holds feeds the next build even when its save failed")
    }

    func testAddAndDeleteSet() {
        let store = Store(inMemory: true)
        let workout = store.startQuickWorkout()
        store.addExercise(named: "Squat", muscle: .quads, to: workout)
        let exercise = workout.exercises[0]
        exercise.sets[0].weight = 225
        exercise.sets[0].reps = 5

        store.addSet(to: exercise)
        XCTAssertEqual(
            exercise.sortedSets.map { "\($0.weight)x\($0.reps)" }, ["225.0x5", "225.0x5"],
            "the new set copies the last one")
        XCTAssertFalse(store.context.hasChanges)

        store.deleteSet(exercise.sortedSets[0], from: exercise)
        XCTAssertEqual(exercise.sets.count, 1)
        XCTAssertEqual(try store.context.fetchCount(FetchDescriptor<SetEntry>()), 1, "the deleted set leaves the store")
        XCTAssertFalse(store.context.hasChanges)
    }

    func testSwapAndRemoveExercise() throws {
        let store = Store(inMemory: true)
        finishedBench(store)
        try store.startMesocycle(twoDayDraft())
        let meso = try XCTUnwrap(store.context.fetch(Mesocycle.active).first)
        let session = store.buildSession(meso, at: day2)
        let row = session.sortedExercises[0]
        let before = row.sets.count

        store.swapExercise(row, to: "Bench Press", muscle: .chest)
        XCTAssertEqual(row.name, "Bench Press")
        XCTAssertEqual(row.muscle, .chest)
        XCTAssertEqual(row.sets.count, before, "a swap keeps the set count")
        XCTAssertTrue(
            row.sets.allSatisfy { $0.targetWeight != nil }, "targets come from the lifter's Bench Press history")
        XCTAssertFalse(store.context.hasChanges)

        store.removeExercise(row, from: session)
        XCTAssertTrue(session.exercises.isEmpty)
        XCTAssertEqual(
            try store.context.fetch(FetchDescriptor<Exercise>(predicate: #Predicate { $0.workout == nil })).count, 0,
            "the removed exercise and its sets leave the store, none is orphaned")
        XCTAssertFalse(store.context.hasChanges)
    }

    func testRecordSorenessAnswersThePendingPrompt() throws {
        let (store, meso) = try startedStore()
        let first = store.buildSession(meso, at: day1)
        store.log(first.sortedExercises[0].sortedSets[0], done: true)
        first.updateFeedback(for: .chest) { $0.pump = .great }
        store.finish(first)
        let next = store.buildSession(meso, at: SessionKey(week: 1, dayIndex: 0))
        next.startDate = first.startDate + 86_400
        let record = try XCTUnwrap(next.pendingSoreness[.chest], "the next chest day asks how the last one recovered")

        store.recordSoreness(.healedOnTime, on: record, during: next)

        XCTAssertEqual(
            first.feedbackRecord(for: .chest)?.value.soreness, .healedOnTime,
            "the answer lands on the session it describes")
        XCTAssertTrue(next.pendingSoreness.isEmpty, "the prompt clears")
        XCTAssertFalse(store.context.hasChanges)
    }

    func testDeleteUnfinishedSessionDetachesItFromItsBlock() throws {
        let (store, meso) = try startedStore()
        let workout = store.buildSession(meso, at: day1)
        XCTAssertIdentical(workout.mesocycle, meso)
        XCTAssertIdentical(workout.exercises[0].workout, workout)
        XCTAssertIdentical(workout.exercises[0].sets[0].exercise, workout.exercises[0])

        store.delete(workout)

        XCTAssertTrue(meso.workouts.isEmpty, "the block forgets the day")
        XCTAssertEqual(try store.context.fetchCount(FetchDescriptor<Workout>()), 0)
    }

    func testBackfillIsIdempotent() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("backfill-\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: url) }
        func container() throws -> ModelContainer {
            try ModelContainer(
                for: AppStore.schema, configurations: ModelConfiguration(schema: AppStore.schema, url: url))
        }
        let writer = ModelContext(try container())
        writer.insert(Exercise(name: "Bench Press", order: 0, muscle: .chest))
        MesoPlanner.start(twoDayDraft(), in: writer)
        for exercise in try writer.fetch(FetchDescriptor<Exercise>()) { exercise.exerciseKey = nil }
        for slot in try writer.fetch(FetchDescriptor<DaySlot>()) { slot.exerciseKey = nil }
        try writer.save()

        func rows(_ context: ModelContext, key: (String, String?) -> String? = { $1 }) throws -> [String] {
            let exercises = try context.fetch(FetchDescriptor<Exercise>()).map {
                "exercise \($0.name): \(key($0.name, $0.exerciseKey) ?? "nil")"
            }
            let slots = try context.fetch(FetchDescriptor<DaySlot>()).map {
                "slot \($0.exerciseName): \(key($0.exerciseName, $0.exerciseKey) ?? "nil")"
            }
            return (exercises + slots).sorted()
        }
        let expected = try rows(writer) { name, _ in ExerciseID(folding: name).rawValue }
        XCTAssertEqual(expected.count, 3)

        let store = Store(container: try container(), settings: Settings())
        XCTAssertEqual(try rows(store.context), expected, "opening the store keys every row by its folded name")
        XCTAssertFalse(store.context.hasChanges, "the backfill is saved")
        XCTAssertEqual(store.backfillExerciseKeys(), 0, "a second run writes nothing")

        XCTAssertEqual(try rows(ModelContext(try container())), expected, "the keys are on disk")
    }

    func testWeeklyVolumeAndLastFinishedExercise() throws {
        let store = Store(inMemory: true)
        XCTAssertNil(store.lastFinishedExercise(ExerciseID(folding: "Bench Press")))
        finishedBench(store)
        XCTAssertEqual(
            store.lastFinishedExercise(ExerciseID(folding: "Bench Press"))?.sortedSets.filter(\.isDone).count, 2)

        try store.startMesocycle(twoDayDraft())
        let meso = try XCTUnwrap(store.context.fetch(Mesocycle.active).first)
        let session = store.buildSession(meso, at: day1)
        store.log(session.sortedExercises[0].sortedSets[0], done: true)

        let volumes = store.weeklyVolume(meso, week: 0)
        XCTAssertEqual(volumes.first { $0.muscle == .chest }?.done, 1)
        XCTAssertEqual(volumes.first { $0.muscle == .chest }?.planned, session.sortedExercises[0].sets.count)
        XCTAssertGreaterThan(
            volumes.first { $0.muscle == .back }?.planned ?? 0, 0, "an unbuilt day counts what it would prescribe")
    }
}
