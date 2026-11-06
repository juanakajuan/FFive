import SwiftData
import XCTest

@testable import FFiveCore

@MainActor
final class BodyweightTests: XCTestCase {
    let week0 = SessionKey(week: 0, dayIndex: 0)
    let week1 = SessionKey(week: 1, dayIndex: 0)
    let pullUp = ExerciseID(folding: "Pull-Up")

    func blockStore(exercise: String = "Pull-Up", muscle: Muscle = .back) throws -> (Store, Mesocycle) {
        let store = Store(inMemory: true)
        var draft = MesoDraft(template: nil)
        draft.days = [.init(name: "A", slots: [.init(exercise: exercise, muscle: muscle)])]
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

    func testBodyLiftsStepByTheirLoadStep() {
        XCTAssertEqual(Equipment.bodyweightLoadable.increment(.lb), 5)
        XCTAssertEqual(Equipment.assistedMachine.increment(.kg), 2.5)
        XCTAssertEqual(Equipment.bodyweightOnly.increment(.lb), 0)
        XCTAssertEqual(Equipment.bodyweightOnly.increment(.kg), 0)
    }

    func testBodyweightOnlyPastRangeHoldsLoadAndAddsReps() throws {
        let (store, meso) = try blockStore(exercise: "Plank", muscle: .abs)
        let first = store.buildSession(meso, at: week0)
        store.setBodyweight(180, of: first)
        for set in first.sortedExercises[0].sortedSets {
            set.weight = 0
            set.reps = 70
            store.log(set, done: true)
        }
        store.finish(first)
        let target = try XCTUnwrap(store.buildSession(meso, at: week1).sortedExercises[0].sortedSets.first).target

        XCTAssertEqual(target.weight, 0, "no load to add")
        XCTAssertGreaterThan(target.reps ?? 0, 70, "reps keep climbing past the range")
        XCTAssertEqual(first.sortedExercises[0].loading.movedLoad(of: 0), 180, "body weight still counts")
    }

    func testAssistedMachinePastRangeShedsFivePoundsOfAssistance() throws {
        let (store, meso) = try blockStore(exercise: "Assisted Pull-Up", muscle: .back)
        let first = store.buildSession(meso, at: week0)
        store.setBodyweight(180, of: first)
        for set in first.sortedExercises[0].sortedSets {
            set.weight = -40
            set.reps = 16
            store.log(set, done: true)
        }
        store.finish(first)
        let target = try XCTUnwrap(store.buildSession(meso, at: week1).sortedExercises[0].sortedSets.first).target

        XCTAssertEqual(target.weight, -35)
    }

    func targetedExercise(
        _ store: Store, _ name: String, muscle: Muscle, bodyweight: Double?, weight: Double?, reps: Int?
    ) -> (Exercise, SetEntry) {
        let workout = store.startQuickWorkout()
        store.setBodyweight(bodyweight, of: workout)
        store.addExercise(named: name, muscle: muscle, to: workout)
        let exercise = workout.sortedExercises[0]
        let set = exercise.sortedSets[0]
        set.targetWeight = weight
        set.targetReps = reps
        return (exercise, set)
    }

    func testTargetLoadsSpanTheRepRangeAtTheWeeksRIR() throws {
        let store = Store(inMemory: true)
        let (bench, set) = targetedExercise(
            store, "Bench Press", muscle: .chest, bodyweight: nil, weight: 100, reps: 10)
        let loads = try XCTUnwrap(bench.targetLoads(for: set, rir: 2, unit: .lb))

        XCTAssertEqual(loads, 100...110)
    }

    func testEveryLoadInTheTargetRangeStaysInsideTheRepRange() throws {
        let store = Store(inMemory: true)
        let (bench, set) = targetedExercise(
            store, "Bench Press", muscle: .chest, bodyweight: nil, weight: 100, reps: 10)
        let loads = try XCTUnwrap(bench.targetLoads(for: set, rir: 2, unit: .lb))
        let oneRepMax = 100 * (1 + Double(10 + 2) / 30)

        for load in stride(from: loads.lowerBound, through: loads.upperBound, by: 5) {
            let reps = Progression.reps(atLoad: load, rir: 2, oneRepMax: oneRepMax)
            XCTAssertTrue(bench.repRange.contains(reps), "\(load) lb gives \(reps) reps")
        }
    }

    func testTargetLoadsAlwaysContainTheTargetWeight() throws {
        let store = Store(inMemory: true)
        let (bench, set) = targetedExercise(store, "Bench Press", muscle: .chest, bodyweight: nil, weight: 100, reps: 4)
        let loads = try XCTUnwrap(bench.targetLoads(for: set, rir: 2, unit: .lb))

        XCTAssertTrue(loads.contains(100))
    }

    func testNoTargetLoadsWithoutATargetWeightOrReps() {
        let store = Store(inMemory: true)
        let (noWeight, noWeightSet) = targetedExercise(
            store, "Bench Press", muscle: .chest, bodyweight: nil, weight: nil, reps: 10)
        let (noReps, noRepsSet) = targetedExercise(
            store, "Bench Press", muscle: .chest, bodyweight: nil, weight: 100, reps: nil)

        XCTAssertNil(noWeight.targetLoads(for: noWeightSet, rir: 2, unit: .lb))
        XCTAssertNil(noReps.targetLoads(for: noRepsSet, rir: 2, unit: .lb))
    }

    func testBodyweightTargetLoadsNeedBodyweight() throws {
        let store = Store(inMemory: true)
        let (known, knownSet) = targetedExercise(store, "Pull-Up", muscle: .back, bodyweight: 180, weight: 25, reps: 8)
        let (unknown, unknownSet) = targetedExercise(
            store, "Pull-Up", muscle: .back, bodyweight: nil, weight: 25, reps: 8)
        let loads = try XCTUnwrap(known.targetLoads(for: knownSet, rir: 2, unit: .lb))

        XCTAssertTrue(loads.contains(25))
        XCTAssertGreaterThan(loads.upperBound, loads.lowerBound)
        XCTAssertNil(unknown.targetLoads(for: unknownSet, rir: 2, unit: .lb))
    }
}
