import SwiftData
import XCTest

@testable import FFiveCore

@MainActor
final class CustomExerciseTests: XCTestCase {
    let suite = "CustomExerciseTests-\(UUID().uuidString)"
    let zercher = ExerciseID(folding: "Zercher Squat")

    override func tearDown() {
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
    }

    func makeStore(unit: String? = nil) throws -> Store {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        if let unit { defaults.set(unit, forKey: "weightUnit") }
        return Store(inMemory: true, settings: Settings(defaults: defaults))
    }

    func draft(
        _ name: String = "Zercher Squat", muscle: Muscle = .quads, equipment: Equipment = .dumbbell,
        reps: ClosedRange<Int> = 5...8, cue: String = ""
    ) -> CustomExerciseDraft {
        CustomExerciseDraft(
            name: name, muscle: muscle, equipment: equipment, minReps: reps.lowerBound, maxReps: reps.upperBound,
            cue: cue)
    }

    @discardableResult
    func log(_ store: Store, _ name: String, muscle: Muscle, weight: Double = 60) -> Workout {
        let workout = store.startQuickWorkout()
        store.addExercise(named: name, muscle: muscle, to: workout)
        let set = workout.sortedExercises[0].sortedSets[0]
        set.weight = weight
        set.reps = 8
        store.log(set, done: true)
        store.finish(workout)
        return workout
    }

    func testCreatedExerciseCarriesItsEquipmentAndRepsIntoListingsAndLoggedRows() throws {
        let store = try makeStore()
        try store.saveCustomExercise(draft(cue: "  Elbows tight  "))

        let listing = try XCTUnwrap(store.library(muscle: .quads, equipment: .dumbbell, search: "zercher").first)
        XCTAssertTrue(listing.isCustom)
        XCTAssertEqual(listing.equipment, "Dumbbell")
        XCTAssertEqual(listing.info.cue, "Elbows tight", "the cue is trimmed")

        let workout = log(store, "Zercher Squat", muscle: .quads)
        let row = try XCTUnwrap(workout.sortedExercises.first)
        XCTAssertEqual(row.info?.equipment, .dumbbell)
        XCTAssertEqual(row.repRange, 5...8)
        XCTAssertEqual(store.customExercise(zercher)?.repRange, 5...8)
    }

    func testPlannerTargetsUseTheCustomRepRangeAndIncrement() throws {
        let store = try makeStore(unit: "kg")
        try store.saveCustomExercise(draft())
        log(store, "Zercher Squat", muscle: .quads, weight: 60)

        var plan = MesoDraft(template: nil)
        plan.days = [.init(name: "Legs", slots: [.init(exercise: "Zercher Squat", muscle: .quads)])]
        try store.startMesocycle(plan)
        let meso = try XCTUnwrap(store.context.fetch(Mesocycle.active).first)
        let session = store.buildSession(meso, at: SessionKey(week: 0, dayIndex: 0))

        let reps = Progression.startingReps(in: 5...8)
        let rir = try XCTUnwrap(meso.phase(week: 0).rir)
        let load = Progression.load(
            forReps: reps, rir: rir, oneRepMax: Progression.estimatedOneRepMax(weight: 60, reps: 8),
            increment: Equipment.dumbbell.increment(.kg), offset: 0)
        let target = try XCTUnwrap(session.sortedExercises.first?.sortedSets.first?.target)
        XCTAssertEqual(target, SetTarget(weight: load, reps: reps))
    }

    func testRenameMovesLoggedRowsSlotsAndPinnedNote() throws {
        let store = try makeStore()
        try store.saveCustomExercise(draft())
        let first = log(store, "Zercher Squat", muscle: .quads)
        let row = try XCTUnwrap(first.sortedExercises.first)
        store.setNote("brace", on: row)
        store.pinNote(on: row)
        var plan = MesoDraft(template: nil)
        plan.days = [.init(name: "Legs", slots: [.init(exercise: "Zercher Squat", muscle: .quads)])]
        store.saveTemplate(from: plan, named: "Legs")
        try store.startMesocycle(plan)

        let custom = try XCTUnwrap(store.customExercise(zercher))
        try store.saveCustomExercise(draft("Front Zercher", muscle: .glutes), editing: custom)

        let renamed = ExerciseID(folding: "Front Zercher")
        XCTAssertNil(store.customExercise(zercher))
        XCTAssertEqual(row.name, "Front Zercher")
        XCTAssertEqual(row.key, renamed)
        XCTAssertEqual(row.muscle, .glutes)
        XCTAssertEqual(try store.context.fetch(FetchDescriptor<DaySlot>()).map(\.key), [renamed])
        XCTAssertEqual(store.pinnedNote(on: row), "brace")
        XCTAssertEqual(
            try store.context.fetch(CustomTemplate.all).first?.template.days.first?.exerciseNames, ["Front Zercher"])
        XCTAssertEqual(
            store.lastFinishedExercise(renamed)?.workout?.name, first.name, "history is found by the new key")
    }

    func testSaveReturnsTheListingAsStored() throws {
        let store = try makeStore()
        let saved = try store.saveCustomExercise(draft("  Zercher Squat \n", muscle: .quads, reps: -2...0))

        XCTAssertEqual(saved.id, zercher)
        XCTAssertEqual(saved.name, "Zercher Squat", "the name is the one the store kept")
        XCTAssertEqual(saved.info.repRange, 1...1)
        XCTAssertEqual(saved, store.listing(zercher))
    }

    func testRenameThatOnlyChangesCaseKeepsTheIdentityAndPinnedNote() throws {
        let store = try makeStore()
        let created = try store.saveCustomExercise(draft())
        let row = try XCTUnwrap(log(store, "Zercher Squat", muscle: .quads).sortedExercises.first)
        store.setNote("brace", on: row)
        store.pinNote(on: row)
        let custom = try XCTUnwrap(store.customExercise(zercher))

        let recased = try store.saveCustomExercise(draft("ZERCHER Squat"), editing: custom)
        XCTAssertEqual(recased.id, created.id)
        XCTAssertEqual(recased.name, "ZERCHER Squat")
        XCTAssertEqual(store.pinnedNote(named: recased.name), "brace")

        let renamed = try store.saveCustomExercise(draft("Front Zercher"), editing: custom)
        XCTAssertNotEqual(renamed.id, created.id)
        XCTAssertEqual(renamed, store.listing(ExerciseID(folding: "Front Zercher")))
    }

    func testNameCollisionsAreRejected() throws {
        let store = try makeStore()
        XCTAssertThrowsError(try store.saveCustomExercise(draft("bench  press"))) {
            XCTAssertEqual($0 as? StoreError, .nameTaken)
        }
        try store.saveCustomExercise(draft())
        XCTAssertThrowsError(try store.saveCustomExercise(draft("ZERCHER squat"))) {
            XCTAssertEqual($0 as? StoreError, .nameTaken)
        }
        let other = draft("Other")
        try store.saveCustomExercise(other)
        let editing = try XCTUnwrap(store.customExercise(ExerciseID(folding: "Other")))
        XCTAssertThrowsError(try store.saveCustomExercise(draft("Zercher Squat"), editing: editing))
        XCTAssertNoThrow(
            try store.saveCustomExercise(draft("OTHER", reps: 1...3), editing: editing), "keeps its own name")
        XCTAssertThrowsError(try store.saveCustomExercise(draft("  ")))
    }

    func testRepRangeIsClamped() throws {
        let store = try makeStore()
        try store.saveCustomExercise(draft(reps: -2...0))
        XCTAssertEqual(store.customExercise(zercher)?.repRange, 1...1)

        var inverted = draft("Inverted")
        inverted.minReps = 9
        inverted.maxReps = 3
        try store.saveCustomExercise(inverted)
        XCTAssertEqual(store.customExercise(ExerciseID(folding: "Inverted"))?.repRange, 9...9)
    }

    func testBlankCueIsSavedAsNoCue() throws {
        let store = try makeStore()
        try store.saveCustomExercise(draft(cue: "  \n"))
        XCTAssertNil(try XCTUnwrap(store.customExercise(zercher)).cue)
        XCTAssertNil(try XCTUnwrap(store.library(muscle: .quads, equipment: nil, search: "zercher").first).info.cue)
    }

    func testDeleteWithoutReferencesRemovesIt() throws {
        let store = try makeStore()
        try store.saveCustomExercise(draft())

        XCTAssertEqual(store.deleteCustomExercise(try XCTUnwrap(store.customExercise(zercher))), .deleted)

        XCTAssertNil(store.customExercise(zercher))
        XCTAssertTrue(store.library(muscle: nil, equipment: nil, search: "zercher", includeHidden: true).isEmpty)
    }

    func testDeleteWithHistoryArchivesIt() throws {
        let store = try makeStore()
        try store.saveCustomExercise(draft())
        let workout = log(store, "Zercher Squat", muscle: .quads)

        XCTAssertEqual(store.deleteCustomExercise(try XCTUnwrap(store.customExercise(zercher))), .archived)

        XCTAssertTrue(store.library(muscle: nil, equipment: nil, search: "zercher").isEmpty, "pickers skip it")
        let archived = try XCTUnwrap(
            store.library(muscle: nil, equipment: nil, search: "zercher", includeHidden: true).first)
        XCTAssertTrue(archived.isHidden)
        XCTAssertEqual(workout.sortedExercises.first?.info?.equipment, .dumbbell, "history keeps its definition")
        XCTAssertNotNil(store.lastFinishedExercise(zercher))

        store.setHidden(zercher, false)
        XCTAssertEqual(store.library(muscle: nil, equipment: nil, search: "zercher").count, 1)
    }

    func testHidingACatalogExerciseSurvivesRelaunch() throws {
        let store = try makeStore()
        let bench = ExerciseID(folding: "Bench Press")

        store.setHidden(bench, true)
        XCTAssertFalse(store.library(muscle: nil, equipment: nil, search: "bench press").contains { $0.id == bench })
        XCTAssertTrue(
            store.library(muscle: nil, equipment: nil, search: "bench press", includeHidden: true)
                .contains { $0.id == bench && $0.isHidden })

        let relaunched = try makeStore()
        XCTAssertTrue(relaunched.isHidden(bench), "the choice is read from the same defaults")

        relaunched.setHidden(bench, false)
        XCTAssertTrue(
            relaunched.library(muscle: nil, equipment: nil, search: "bench press").contains { $0.id == bench })
        XCTAssertFalse(try makeStore().isHidden(bench))
    }

    func testBackfillRecordsEveryUsedNonCatalogExerciseOnce() throws {
        let store = try makeStore()
        let workout = store.startQuickWorkout()
        for (order, name) in ["Cafe Curl", "Café Curl", "Bench Press"].enumerated() {
            workout.exercises.append(
                Exercise(name: name, order: order, muscle: name == "Bench Press" ? .chest : .biceps))
        }
        var plan = MesoDraft(template: nil)
        plan.days = [.init(name: "A", slots: [.init(exercise: "Odd Lift", muscle: .back)])]
        store.saveTemplate(from: plan, named: "T")
        let slot = DaySlot(exerciseName: "Slot Lift", muscle: .abs, order: 0)
        let day = MesoDay(name: "D", order: 0)
        day.slots.append(slot)
        store.context.insert(day)
        store.commit()

        XCTAssertEqual(store.backfillCustomExercises(), 3, "one per folded name, from rows, slots and templates")
        XCTAssertEqual(store.backfillCustomExercises(), 0, "a second run adds nothing")

        let record = try XCTUnwrap(store.customExercise(ExerciseID(folding: "Odd Lift")))
        XCTAssertEqual(record.equipment, .machine)
        XCTAssertEqual(record.repRange, 8...12)
        XCTAssertEqual(record.muscle, .back)
        XCTAssertNil(store.customExercise(ExerciseID(folding: "Bench Press")), "catalog names get no record")
    }
}
