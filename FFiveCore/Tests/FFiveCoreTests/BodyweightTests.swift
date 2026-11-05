import SwiftData
import XCTest

@testable import FFiveCore

@MainActor
final class BodyweightTests: XCTestCase {
    let week0 = SessionKey(week: 0, dayIndex: 0)
    let week1 = SessionKey(week: 1, dayIndex: 0)
    let pullUp = ExerciseID(folding: "Pull-Up")

    func blockStore() throws -> (Store, Mesocycle) {
        let store = Store(inMemory: true)
        var draft = MesoDraft(template: nil)
        draft.days = [.init(name: "A", slots: [.init(exercise: "Pull-Up", muscle: .back)])]
        try store.startMesocycle(draft)
        return (store, try XCTUnwrap(store.context.fetch(Mesocycle.active).first))
    }

    /// Week 1's first target for the pull-up after week 0 was logged at `weight` x `reps`.
    func progressedTarget(
        weight: Double, reps: Int, bodyweight: Double?, file: StaticString = #filePath, line: UInt = #line
    ) throws -> SetTarget {
        let (store, meso) = try blockStore()
        let first = store.buildSession(meso, at: week0)
        store.setBodyweight(bodyweight, of: first)
        for set in first.sortedExercises[0].sortedSets {
            set.weight = weight
            set.reps = reps
            store.log(set, done: true)
        }
        store.finish(first)
        let second = store.buildSession(meso, at: week1)
        return try XCTUnwrap(second.sortedExercises[0].sortedSets.first, file: file, line: line).target
    }

    func loggedPullUp(_ store: Store, bodyweight: Double?, weight: Double, reps: Int) -> Workout {
        let workout = store.startQuickWorkout()
        store.setBodyweight(bodyweight, of: workout)
        store.addExercise(named: "Pull-Up", muscle: .back, to: workout)
        let set = workout.exercises[0].sets[0]
        set.weight = weight
        set.reps = reps
        store.log(set, done: true)
        store.finish(workout)
        return workout
    }

    func testWeightedPullUpPastRangeAddsLoadAndResolvesRepsFromBodyweightInclusiveOneRepMax() throws {
        let target = try progressedTarget(weight: 25, reps: 12, bodyweight: 180)

        XCTAssertEqual(target.weight, 30, "5 lb more added load")
        XCTAssertEqual(target.reps, 11, "reps come from the 205 lb moved load's 1RM, not from 25 lb")
    }

    func testAssistedSetPastRangeShedsAssistance() throws {
        let target = try progressedTarget(weight: -40, reps: 12, bodyweight: 180)

        XCTAssertEqual(target.weight, -35)
        XCTAssertEqual(target.reps, 11)
    }

    func testUnknownBodyweightHoldsLoadAndAddsReps() throws {
        let target = try progressedTarget(weight: 25, reps: 12, bodyweight: nil)

        XCTAssertEqual(target, SetTarget(weight: 25, reps: 13))
    }

    func testStrengthSeriesRanksByMovedLoadAndLabelsTheSet() throws {
        let store = Store(inMemory: true)
        _ = loggedPullUp(store, bodyweight: 180, weight: 25, reps: 8)

        let point = try XCTUnwrap(store.strengthSeries().first { $0.id == pullUp }?.points.first)
        XCTAssertEqual(point.value, Progression.estimatedOneRepMax(weight: 205, reps: 8, rir: 0), accuracy: 0.001)
        XCTAssertEqual(point.bestSet, "BW+25 × 8")
    }

    func testBodyweightLiftWithoutBodyweightGivesNoStrengthPoint() {
        let store = Store(inMemory: true)
        _ = loggedPullUp(store, bodyweight: nil, weight: 25, reps: 8)

        XCTAssertNil(store.strengthSeries().first { $0.id == pullUp })
    }

    func testBodyweightAloneCountsAsStrength() throws {
        let store = Store(inMemory: true)
        let workout = loggedPullUp(store, bodyweight: 180, weight: 0, reps: 8)

        let strongest = try XCTUnwrap(workout.exercises[0].strongestSet)
        XCTAssertEqual(
            strongest.oneRepMax, Progression.estimatedOneRepMax(weight: 180, reps: 8, rir: 0), accuracy: 0.001)
    }

    func testVolumeCountsTheMovedLoadOfABodyweightLift() {
        let store = Store(inMemory: true)

        XCTAssertEqual(loggedPullUp(store, bodyweight: 180, weight: -40, reps: 10).totalVolume, 1400)
        XCTAssertEqual(loggedPullUp(store, bodyweight: nil, weight: 25, reps: 8).totalVolume, 0)
    }

    func testBodyweightCarriesIntoQuickWorkoutAndBlockSession() throws {
        let (store, meso) = try blockStore()
        let open = store.startQuickWorkout()
        store.setBodyweight(180, of: open)

        XCTAssertEqual(store.startQuickWorkout().bodyweight, 180, "an unfinished workout's body weight counts")
        XCTAssertEqual(store.buildSession(meso, at: week0).bodyweight, 180)
    }

    func testSetBodyweightClearsOnZeroOrNil() {
        let store = Store(inMemory: true)
        let workout = store.startQuickWorkout()

        store.setBodyweight(180, of: workout)
        XCTAssertEqual(workout.bodyweight, 180)
        store.setBodyweight(0, of: workout)
        XCTAssertNil(workout.bodyweight)
        store.setBodyweight(180, of: workout)
        store.setBodyweight(nil, of: workout)
        XCTAssertNil(workout.bodyweight)
        XCTAssertNil(store.failure)
    }

    func testFreshTargetForBodyweightLiftIsRoundedAddedLoad() throws {
        let (store, meso) = try blockStore()
        _ = loggedPullUp(store, bodyweight: 180, weight: 25, reps: 8)

        let session = store.buildSession(meso, at: week0)

        let oneRepMax = Progression.estimatedOneRepMax(weight: 205, reps: 8, rir: 0)
        let reps = Progression.startingReps(in: ExerciseCatalog.repRange(for: pullUp))
        let moved = oneRepMax / (1 + Double(reps + 3) / 30)
        let expected = Progression.roundDown(moved - 180, to: 5)
        XCTAssertEqual(expected, 10, "the arithmetic itself: 194.75 moved less 180, rounded down to 5")
        XCTAssertEqual(
            session.sortedExercises[0].sortedSets.first?.target, SetTarget(weight: expected, reps: reps))
    }

    func testFreshTargetCalibratesWithoutBodyweight() throws {
        let (store, meso) = try blockStore()
        _ = loggedPullUp(store, bodyweight: nil, weight: 25, reps: 8)

        let session = store.buildSession(meso, at: week0)

        XCTAssertEqual(session.sortedExercises[0].sortedSets.first?.target, .calibrate)
    }

    func testWeightTextForBodyweightAndExternalLifts() throws {
        let store = Store(inMemory: true)
        let workout = store.startQuickWorkout()
        store.addExercise(named: "Pull-Up", muscle: .back, to: workout)
        store.addExercise(named: "Bench Press", muscle: .chest, to: workout)
        let pull = workout.sortedExercises[0]
        let bench = workout.sortedExercises[1]

        XCTAssertEqual(pull.weightText(0), "BW")
        XCTAssertEqual(pull.weightText(25), "BW+25")
        XCTAssertEqual(pull.weightText(-40), "BW\u{2212}40")
        XCTAssertEqual(pull.weightText(2.5, unit: .kg), "BW+2.5")
        XCTAssertEqual(bench.weightText(135), "135")
        XCTAssertEqual(bench.weightText(135, unit: .lb), "135 lb")
    }

    func testBodyweightStepIsTheAddedLoadStep() {
        XCTAssertEqual(Equipment.bodyweight.increment(.lb), 5)
        XCTAssertEqual(Equipment.bodyweight.increment(.kg), 2.5)
    }
}
