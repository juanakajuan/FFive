import Foundation
import XCTest

@testable import FFiveCore

@MainActor
final class CoachingTipTests: XCTestCase {
    let suite = "CoachingTipTests-\(UUID().uuidString)"

    override func tearDown() {
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
    }

    func firstBlockSession() throws -> (Store, Exercise) {
        let store = Store(inMemory: true)
        var draft = MesoDraft(template: nil)
        draft.days = [.init(name: "A", slots: [.init(exercise: "Bench Press", muscle: .chest)])]
        try store.startMesocycle(draft)
        let meso = try XCTUnwrap(store.context.fetch(Mesocycle.active).first)
        let workout = store.buildSession(meso, at: SessionKey(week: 0, dayIndex: 0))
        return (store, try XCTUnwrap(workout.sortedExercises.first))
    }

    func logFirstSet(of exercise: Exercise, in store: Store) {
        let set = exercise.sortedSets[0]
        set.weight = 100
        set.reps = 10
        store.log(set, done: true)
    }

    func testACalibrationSetGetsTheStartingLoadTipThenRestAfterALog() throws {
        let (store, bench) = try firstBlockSession()
        XCTAssertNil(bench.sortedSets[0].targetWeight, "week one has no history, so it calibrates")
        XCTAssertEqual(CoachingTip.applicable(to: bench, dismissed: []), .startingLoad)

        logFirstSet(of: bench, in: store)
        XCTAssertEqual(CoachingTip.applicable(to: bench, dismissed: []), .rest, "a logged set with more to come")

        for set in bench.sortedSets where !set.isDone {
            set.weight = 100
            set.reps = 10
            store.log(set, done: true)
        }
        XCTAssertNil(CoachingTip.applicable(to: bench, dismissed: []), "no tip once every set is logged")
    }

    func testADismissedTipStaysHidden() throws {
        let (store, bench) = try firstBlockSession()
        XCTAssertNil(CoachingTip.applicable(to: bench, dismissed: [.startingLoad]))
        logFirstSet(of: bench, in: store)
        XCTAssertNil(CoachingTip.applicable(to: bench, dismissed: [.rest]))
    }

    func testAQuickWorkoutHasNoStartingLoadTip() throws {
        let store = Store(inMemory: true)
        let workout = store.startQuickWorkout()
        store.addExercise(named: "Bench Press", muscle: .chest, to: workout)
        let bench = workout.exercises[0]
        store.addSet(to: bench)
        XCTAssertNil(CoachingTip.applicable(to: bench, dismissed: []), "no block, no target RIR to calibrate to")

        logFirstSet(of: bench, in: store)
        XCTAssertEqual(CoachingTip.applicable(to: bench, dismissed: []), .rest)
    }

    func testDismissalPersistsAcrossLaunches() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        XCTAssertEqual(Settings(defaults: defaults).dismissedTips, [])

        Settings(defaults: defaults).dismiss(.rest)
        XCTAssertEqual(Settings(defaults: defaults).dismissedTips, [.rest])
    }
}
