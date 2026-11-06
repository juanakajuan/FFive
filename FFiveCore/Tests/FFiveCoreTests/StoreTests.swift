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
        store.logEntered(started.sortedExercises[0].sortedSets[0])
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

    func testResetClearsLoggedSetsAndKeepsThePrescription() throws {
        let (store, meso) = try startedStore()
        let workout = store.buildSession(meso, at: day1)
        let sets = workout.sortedExercises.flatMap(\.sortedSets)
        let target = 60.0
        sets[0].targetWeight = target
        sets[0].targetReps = 8
        sets[0].weight = target + 10
        sets[0].reps = 11
        store.setType(.myorep, of: sets[0])
        store.log(sets[0], done: true)
        sets[1].targetWeight = nil
        sets[1].targetReps = nil
        sets[1].weight = 100
        sets[1].reps = 8
        store.log(sets[1], done: true)
        store.skip(sets[2], skipped: true)
        workout.updateFeedback(for: .chest) { $0.pump = .moderate }
        let exerciseNames = workout.sortedExercises.map(\.name)

        store.reset(workout)

        XCTAssertEqual(workout.completedSets, 0)
        XCTAssertEqual(workout.sortedExercises.map(\.name), exerciseNames)
        XCTAssertEqual(workout.sortedExercises.flatMap(\.sortedSets).count, sets.count)
        XCTAssertEqual(sets[0].weight, target)
        XCTAssertEqual(sets[0].reps, 8)
        XCTAssertEqual(sets[0].type, .regular)
        XCTAssertEqual(sets[1].weight, 0, "a set with no target goes back to an empty row")
        XCTAssertEqual(sets[1].reps, 0)
        XCTAssertEqual(sets[2].status, .pending, "a skipped set waits to be logged again")
        XCTAssertTrue(workout.feedback.isEmpty)
        XCTAssertEqual(try store.context.fetchCount(FetchDescriptor<MuscleFeedbackRecord>()), 0)
        XCTAssertNil(store.failure)
    }

    func testRenamingAMesoWorkoutRenamesItsDayEverywhere() throws {
        let (store, meso) = try startedStore()
        let first = store.buildSession(meso, at: day1)
        let other = store.buildSession(meso, at: day2)

        store.rename(first, to: "  Push  ")

        XCTAssertEqual(first.name, "Push")
        XCTAssertEqual(meso.dayNames, ["Push", "B"])
        XCTAssertEqual(other.name, "B")
        let later = store.buildSession(meso, at: SessionKey(week: 1, dayIndex: 0))
        XCTAssertEqual(later.name, "Push", "later weeks are built with the new name")
        store.rename(later, to: "Pull")
        XCTAssertEqual(first.name, "Pull", "sessions of the same day agree")
    }

    func testRenamingAQuickWorkoutChangesOnlyIt() throws {
        let (store, meso) = try startedStore()
        let day = store.buildSession(meso, at: day1)
        let quick = Workout(name: "Quick")
        store.context.insert(quick)

        store.rename(quick, to: "Arms")

        XCTAssertEqual(quick.name, "Arms")
        XCTAssertEqual(day.name, "A")
        XCTAssertEqual(meso.dayNames, ["A", "B"])
    }

    func testRenameIgnoresEmptyNames() throws {
        let (store, meso) = try startedStore()
        let workout = store.buildSession(meso, at: day1)

        store.rename(workout, to: "   ")

        XCTAssertEqual(workout.name, "A")
        XCTAssertEqual(meso.dayNames, ["A", "B"])
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
        for set in workout.exercises[0].sortedSets {
            set.weight = 100
            set.reps = 8
            store.log(set, done: true)
        }
        store.finish(workout)
    }

    func testASetNeedsRepsAndWeightBeforeItLogs() throws {
        let store = Store(inMemory: true)
        let workout = store.startQuickWorkout()
        store.addExercise(named: "Bench Press", muscle: .chest, to: workout)
        let set = workout.exercises[0].sortedSets[0]
        set.weight = 0
        set.reps = 0

        store.log(set, done: true)
        XCTAssertFalse(set.isDone, "an empty set does not log")
        set.reps = 8
        store.log(set, done: true)
        XCTAssertFalse(set.isDone, "reps without a weight do not log")
        set.weight = 100
        store.log(set, done: true)
        XCTAssertTrue(set.isDone)

        store.addExercise(named: "Pull-Up", muscle: .back, to: workout)
        let pullUp = try XCTUnwrap(workout.sortedExercises.last?.sortedSets.first)
        pullUp.weight = 0
        pullUp.reps = 8
        store.log(pullUp, done: true)
        XCTAssertTrue(pullUp.isDone, "a bodyweight set logs with no added weight")
    }

    func testSetsLogInOrder() throws {
        let store = Store(inMemory: true)
        let workout = store.startQuickWorkout()
        store.addExercise(named: "Bench Press", muscle: .chest, to: workout)
        let exercise = workout.exercises[0]
        while exercise.sets.count < 3 { store.addSet(to: exercise) }
        let sets = exercise.sortedSets
        for set in sets {
            set.weight = 100
            set.reps = 8
        }

        store.log(sets[1], done: true)
        XCTAssertFalse(sets[1].isDone, "set 2 waits for set 1")
        store.log(sets[0], done: true)
        store.log(sets[1], done: true)
        XCTAssertEqual(sets.map(\.status), [.done, .done, .pending])

        store.log(sets[0], done: false)
        XCTAssertTrue(sets[0].isDone, "set 1 stays logged while set 2 is")
        store.log(sets[1], done: false)
        store.log(sets[0], done: false)
        XCTAssertEqual(sets.map(\.status), [.pending, .pending, .pending], "sets unlog from the last one back")

        store.skip(sets[0], skipped: true)
        store.log(sets[1], done: true)
        XCTAssertTrue(sets[1].isDone, "a skipped set does not hold up the next one")
    }

    func testLogSetRestartsUntouchedClock() throws {
        let (store, meso) = try startedStore()
        let workout = store.buildSession(meso, at: day1)
        let sets = workout.sortedExercises[0].sortedSets
        let shown = Date.now - 600
        workout.startDate = shown

        store.logEntered(sets[0])
        XCTAssertGreaterThan(workout.startDate, shown + 590, "the first logged set starts the session clock")
        XCTAssertTrue(sets[0].isDone)
        XCTAssertFalse(store.context.hasChanges, "the log is saved")

        let started = workout.startDate
        store.logEntered(sets[1])
        XCTAssertEqual(workout.startDate, started, "later sets leave the clock alone")
        store.log(sets[1], done: false)
        XCTAssertFalse(sets[1].isDone, "a set can be unlogged")
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
            increment: ExerciseCatalog.loading(for: key, bodyweight: nil).increment(store.settings.weightUnit),
            offset: 0)
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

    func autoMatchSetup() throws -> (Store, [SetEntry]) {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "auto-\(UUID().uuidString)"))
        let store = Store(inMemory: true, settings: Settings(defaults: defaults))
        let workout = store.startQuickWorkout()
        store.addExercise(named: "Squat", muscle: .quads, to: workout)
        let exercise = workout.exercises[0]
        while exercise.sets.count < 5 { store.addSet(to: exercise) }
        let sets = exercise.sortedSets
        for (set, weight) in zip(sets, [200, 200, 185, 200, 200]) { set.weight = Double(weight) }
        sets[4].status = .done
        return (store, sets)
    }

    func testWeightEditCarriesToLaterUnloggedSetsOfTheSameWeight() throws {
        let (store, sets) = try autoMatchSetup()
        let followers = store.weightFollowers(of: sets[1])
        store.setWeight(225, of: sets[1], carryingTo: followers)
        XCTAssertEqual(sets.map(\.weight), [200, 225, 185, 225, 200], "only the later pending 200 follows")
        XCTAssertFalse(store.context.hasChanges)
    }

    func testFollowersCapturedUpFrontIgnoreATransientZero() throws {
        let (store, sets) = try autoMatchSetup()
        sets[2].weight = 0
        let followers = store.weightFollowers(of: sets[1])
        store.setWeight(0, of: sets[1], carryingTo: followers)
        store.setWeight(225, of: sets[1], carryingTo: followers)
        XCTAssertEqual(sets.map(\.weight), [200, 225, 0, 225, 200], "an empty later set is not swept in")
    }

    func testToggleOffLeavesNoFollowers() throws {
        let (store, sets) = try autoMatchSetup()
        store.settings.autoMatchWeights = false
        XCTAssertTrue(store.weightFollowers(of: sets[0]).isEmpty)
    }

    func testTypedWeightAndRepsAreSavedBeforeTheSetIsLogged() throws {
        let store = Store(inMemory: true)
        let workout = store.startQuickWorkout()
        store.addExercise(named: "Squat", muscle: .quads, to: workout)
        let set = workout.exercises[0].sortedSets[0]
        store.setWeight(123, of: set, carryingTo: [])
        XCTAssertFalse(store.context.hasChanges, "the weight is saved")
        store.setReps(8, of: set)
        XCTAssertFalse(store.context.hasChanges, "the reps are saved")
        let saved = try ModelContext(store.container).fetch(FetchDescriptor<SetEntry>())
        XCTAssertEqual(saved.map(\.weight), [123])
        XCTAssertEqual(saved.map(\.reps), [8])
        XCTAssertFalse(set.isDone)
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

    func testSkippedSetsLetTheSessionFinish() throws {
        let (store, meso) = try startedStore()
        let workout = store.buildSession(meso, at: day1)
        let exercise = workout.sortedExercises[0]
        let sets = exercise.sortedSets
        XCTAssertGreaterThan(sets.count, 2)

        store.logEntered(sets[0])
        store.skip(sets[1], skipped: true)
        XCTAssertEqual(sets[1].status, .skipped)
        XCTAssertFalse(workout.isFullyLogged, "a pending set still blocks finishing")

        store.skipRemainingSets(of: exercise)
        XCTAssertEqual(sets.map(\.status), [.done] + Array(repeating: .skipped, count: sets.count - 1))
        XCTAssertTrue(workout.isFullyLogged, "skipped sets do not block finishing")
        XCTAssertEqual(workout.setProgress, 1)
        XCTAssertEqual(workout.completedSets, 1, "a skipped set is not a completed one")
        XCTAssertFalse(store.context.hasChanges, "the skip is saved")

        let chest = store.weeklyVolume(meso, week: 0).first { $0.muscle == .chest }
        XCTAssertEqual(chest?.done, 1)
        XCTAssertEqual(chest?.planned, 1, "skipped sets are not missed volume")

        store.logEntered(sets[1])
        XCTAssertEqual(sets[1].status, .done, "logging a skipped set replaces the skip")
        store.skip(sets[2], skipped: false)
        XCTAssertEqual(sets[2].status, .pending, "a skip can be undone")
        XCTAssertNil(store.failure)
    }

    func testSkippedSetsRepeatTheirTargetNextWeek() throws {
        let (store, meso) = try startedStore()
        let workout = store.buildSession(meso, at: day1)
        let sets = workout.sortedExercises[0].sortedSets
        for set in sets {
            set.weight = 100
            set.reps = 10
        }
        store.log(sets[0], done: true)
        store.skipRemainingSets(of: workout.sortedExercises[0])
        store.finish(workout)

        let next = store.buildSession(meso, at: SessionKey(week: 1, dayIndex: 0)).sortedExercises[0].sortedSets
        XCTAssertGreaterThanOrEqual(next.count, sets.count, "skipped sets stay in the prescription")
        for (skipped, planned) in zip(sets.dropFirst(), next.dropFirst()) {
            XCTAssertEqual(planned.targetWeight, skipped.targetWeight, "a skipped set repeats its target load")
            XCTAssertEqual(planned.targetReps, skipped.targetReps, "a skipped set repeats its target reps")
        }
        XCTAssertNil(store.failure)
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

    func testUpdateFeedbackSavesAndFeedsTheCap() throws {
        let (store, meso) = try startedStore()
        let session = store.buildSession(meso, at: day1)
        store.updateFeedback(for: .chest, in: session) { $0.jointPain = .severe }
        XCTAssertFalse(store.context.hasChanges, "a joint pain report is saved right away, not left to autosave")

        store.updateFeedback(for: .chest, in: session) {
            $0.soreness = .never
            $0.workload = .easy
        }
        let feedback = try XCTUnwrap(session.feedbackRecord(for: .chest)).value
        XCTAssertEqual(feedback.jointPain, .severe, "the end-of-muscle answers keep the earlier joint pain report")
        XCTAssertEqual(Progression.setDelta(feedback), 0, "the reported pain caps next week's change at 0")
    }

    func testRecordSorenessAnswersThePendingPrompt() throws {
        let (store, meso) = try startedStore()
        let first = store.buildSession(meso, at: day1)
        store.logEntered(first.sortedExercises[0].sortedSets[0])
        first.updateFeedback(for: .chest) { $0.pump = .great }
        store.finish(first)
        let next = store.buildSession(meso, at: SessionKey(week: 1, dayIndex: 0))
        next.startDate = first.startDate + 86_400
        let record = try XCTUnwrap(
            store.pendingSoreness(in: next)[.chest], "the next chest day asks how the last one recovered")

        store.recordSoreness(.healedOnTime, on: record, during: next)

        XCTAssertEqual(
            first.feedbackRecord(for: .chest)?.value.soreness, .healedOnTime,
            "the answer lands on the session it describes")
        XCTAssertTrue(store.pendingSoreness(in: next).isEmpty, "the prompt clears")
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

    @discardableResult
    func finished(
        _ store: Store, at start: Date, minutes: Double = 60, _ lifts: [(name: String, muscle: Muscle, weight: Double)]
    ) -> Workout {
        let workout = Workout(name: "Logged", startDate: start)
        store.context.insert(workout)
        for (order, lift) in lifts.enumerated() {
            let exercise = Exercise(name: lift.name, order: order, muscle: lift.muscle)
            workout.exercises.append(exercise)
            let set = SetEntry(reps: 8, weight: lift.weight, order: 0)
            set.status = .done
            exercise.sets.append(set)
        }
        workout.endDate = start + minutes * 60
        store.commit()
        return workout
    }

    func testLibraryOrderIsStable() throws {
        let store = Store(inMemory: true)
        finished(
            store, at: .now,
            [
                ("zercher squat", .quads, 60), ("Bench Press", .chest, 100), ("Cafe Curl", .biceps, 20),
                ("Café Curl", .biceps, 20),
            ])

        store.backfillCustomExercises()

        let all = store.library(muscle: nil, equipment: nil, search: "")
        XCTAssertEqual(all.count, ExerciseCatalog.all.count + 2, "custom lifts join the catalog once per folded name")
        XCTAssertTrue(all.contains { $0.name == "zercher squat" && $0.isCustom && $0.equipment == "Machine" })
        XCTAssertEqual(
            all.map(\.name), all.map(\.name).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending },
            "names sort ignoring case, so a lowercase custom name sits among the rest")
        XCTAssertEqual(
            all, store.library(muscle: nil, equipment: nil, search: ""),
            "the same store gives the same order every time")

        let quads = store.library(muscle: .quads, equipment: nil, search: "")
        XCTAssertTrue(quads.allSatisfy { $0.muscle == .quads })
        XCTAssertEqual(
            quads.map(\.id), all.filter { $0.muscle == .quads }.map(\.id), "a muscle filter keeps the full list's order"
        )
        XCTAssertEqual(
            store.library(muscle: nil, equipment: nil, search: "  ZERCHER ").map(\.name), ["zercher squat"],
            "search trims and ignores case")

        let assisted = store.library(muscle: nil, equipment: .assistedMachine, search: "")
        XCTAssertEqual(
            Set(assisted.map(\.name)),
            [
                "Assisted Pull-Up", "Assisted Wide-Grip Pull-Up", "Assisted Neutral-Grip Pull-Up", "Assisted Chin-Up",
                "Assisted Dip",
            ],
            "an equipment filter drops custom lifts, which have none")
        XCTAssertEqual(
            store.library(muscle: .back, equipment: .assistedMachine, search: "").count, 4, "the filters combine")
    }

    func testLibraryFitsTheLifterEquipment() throws {
        let store = Store(inMemory: true)
        finished(store, at: .now, [("zercher squat", .quads, 60)])
        store.backfillCustomExercises()
        let all = store.library(muscle: nil, equipment: nil, search: "")

        let dumbbellOnly = all.filter { $0.fits([.dumbbell]) }
        XCTAssertTrue(dumbbellOnly.contains { $0.name == "zercher squat" }, "a custom exercise always fits")
        XCTAssertTrue(
            dumbbellOnly.allSatisfy { $0.isCustom || $0.info.equipment == .dumbbell },
            "catalog exercises of other equipment are filtered out")
        XCTAssertTrue(
            dumbbellOnly.contains { !$0.isCustom && $0.info.equipment == .dumbbell }, "dumbbell exercises stay")
        XCTAssertLessThan(dumbbellOnly.count, all.count)
        XCTAssertEqual(all.filter { $0.fits(Set(Equipment.allCases)) }, all, "owning everything hides nothing")
    }

    func testWeekStatsMatchHistory() throws {
        let store = Store(inMemory: true)
        let now = try XCTUnwrap(Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 4, hour: 12)))
        let weekStart = try XCTUnwrap(Calendar.current.dateInterval(of: .weekOfYear, for: now)?.start)
        XCTAssertEqual(store.weekStats(now: now), WeekStats(thisWeek: 0, time: 0, allTime: 0))

        finished(store, at: weekStart + 60, minutes: 45, [("Bench Press", .chest, 100)])
        finished(store, at: now - 3600, minutes: 30, [("Barbell Row", .back, 80)])
        finished(store, at: weekStart - 60, minutes: 50, [("Bench Press", .chest, 100)])
        store.startQuickWorkout()

        let history = try store.context.fetch(Workout.history)
        let thisWeek = history.filter { $0.startDate >= weekStart }
        XCTAssertEqual(
            store.weekStats(now: now),
            WeekStats(thisWeek: thisWeek.count, time: thisWeek.reduce(0) { $0 + $1.duration }, allTime: history.count))
        XCTAssertEqual(
            store.weekStats(now: now), WeekStats(thisWeek: 2, time: 75 * 60, allTime: 3),
            "an open workout and last week's session stay out of this week")
    }

    func testStrengthSeriesPointsKeepTheirIdentity() throws {
        let store = Store(inMemory: true)
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        finished(store, at: start, [("Bench Press", .chest, 100), ("Barbell Row", .back, 80)])
        finished(store, at: start + 86_400, [("Bench Press", .chest, 105), ("bench press", .chest, 110)])
        finished(store, at: start + 2 * 86_400, [("Barbell Row", .back, 85)])

        let series = store.strengthSeries()
        XCTAssertEqual(series.map(\.name), ["Barbell Row", "Bench Press"], "most recently trained first")
        let bench = try XCTUnwrap(series.first { $0.id == ExerciseID(folding: "Bench Press") })
        XCTAssertEqual(bench.points.count, 2, "a session that logs a lift twice gives one point")
        XCTAssertEqual(bench.points.last?.bestSet, "110 × 8", "the stronger of the two sets")
        XCTAssertEqual(Set(bench.points.map(\.id)).count, bench.points.count)
        XCTAssertEqual(store.strengthSeries(), series, "ids come from the lift and the date, so a re-read is equal")
    }

    func testPinnedNoteFollowsTheExercise() throws {
        let store = Store(inMemory: true)
        let workout = store.startQuickWorkout()
        store.addExercise(named: "Bench Press", muscle: .chest, to: workout)
        let exercise = workout.exercises[0]
        XCTAssertNil(store.pinnedNote(on: exercise))
        store.setNote("Elbows in", on: exercise)
        store.pinNote(on: exercise)
        XCTAssertEqual(store.pinnedNote(on: exercise), "Elbows in")
        store.unpinNote(on: exercise)
        XCTAssertNil(store.pinnedNote(on: exercise))
    }

    func testMyorepSetsDoNotDriveNextWeekOrStrength() throws {
        let (store, meso) = try startedStore()
        let week0 = store.buildSession(meso, at: day1)
        let bench = week0.sortedExercises[0]
        let sets = Array(bench.sortedSets.prefix(2))
        for set in sets {
            set.weight = 100
            set.reps = 10
            store.log(set, done: true)
        }
        store.setType(.myorep, of: sets[1])
        XCTAssertEqual(sets[1].type, .myorep, "the type is stored on the set")
        XCTAssertEqual(bench.strongestSet?.entry, sets[0], "a myo-rep set never feeds the strength estimate")
        week0.finish(in: store.context)

        let next = store.buildSession(meso, at: SessionKey(week: 1, dayIndex: 0)).sortedExercises[0].sortedSets
        XCTAssertNotEqual(next[0].target, SetTarget.calibrate, "a regular log turns the calibration into a target")
        XCTAssertEqual(next[1].target, SetTarget.calibrate, "a myo-rep log leaves its slot's target unchanged")
    }

    func testAddSetCopiesTheLastSetType() throws {
        let (store, meso) = try startedStore()
        let bench = store.buildSession(meso, at: day1).sortedExercises[0]
        store.setType(.myorepMatch, of: bench.sortedSets.last!)
        store.addSet(to: bench)
        XCTAssertEqual(bench.sortedSets.last?.type, .myorepMatch)
    }
}

extension Store {
    /// Fills an empty set with a lift, since a set without reps and weight cannot be logged.
    func logEntered(_ set: SetEntry) {
        if set.weight == 0 { set.weight = 100 }
        if set.reps == 0 { set.reps = 8 }
        log(set, done: true)
    }
}
