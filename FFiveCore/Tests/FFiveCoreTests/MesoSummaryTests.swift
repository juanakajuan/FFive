import SwiftData
import XCTest

@testable import FFiveCore

@MainActor
final class MesoSummaryTests: XCTestCase {
    let benchDay = MesoDraft(days: [.init(name: "A", slots: [.init(exercise: "Bench Press", muscle: .chest)])])

    @discardableResult
    func train(
        _ store: Store, _ meso: Mesocycle, week: Int, weight: Double, sets: Int, workload: Workload
    ) -> Workout {
        let workout = store.buildSession(meso, at: SessionKey(week: week, dayIndex: 0))
        for set in workout.sortedExercises[0].sortedSets.prefix(sets) {
            set.weight = weight
            set.reps = 10
            store.log(set, done: true)
        }
        store.updateFeedback(for: .chest, in: workout) { $0.workload = workload }
        store.finish(workout)
        return workout
    }

    func testSummaryCountsDoneSetsPerMuscleEachWeek() throws {
        let (store, meso) = try startedStore(benchDay)
        train(store, meso, week: 0, weight: 60, sets: 2, workload: .easy)
        train(store, meso, week: 1, weight: 65, sets: 3, workload: .tooMuch)

        let summary = meso.summary

        XCTAssertEqual(summary.weeks, meso.totalWeeks)
        XCTAssertEqual(summary.sets.map(\.muscle), [.chest])
        XCTAssertEqual(Array(summary.sets[0].perWeek.prefix(2)), [2, 3])
        XCTAssertEqual(summary.sets[0].perWeek.dropFirst(2).reduce(0, +), 0, "untrained weeks count zero")
    }

    func testSummaryReportsE1RMChangeFromFirstToLastSession() throws {
        let (store, meso) = try startedStore(benchDay)
        train(store, meso, week: 0, weight: 60, sets: 1, workload: .good)
        train(store, meso, week: 1, weight: 70, sets: 1, workload: .good)

        let change = try XCTUnwrap(meso.summary.strength.first)

        XCTAssertEqual(change.name, "Bench Press")
        XCTAssertGreaterThan(change.last, change.first, "a heavier set at the same reps raises the estimate")
        XCTAssertGreaterThan(change.percent, 0)
    }

    func testSummaryTracksFeedbackPerWeek() throws {
        let (store, meso) = try startedStore(benchDay)
        train(store, meso, week: 0, weight: 60, sets: 1, workload: .easy)
        train(store, meso, week: 1, weight: 60, sets: 1, workload: .tooMuch)

        let trend = try XCTUnwrap(meso.summary.feedback.first { $0.muscle == .chest })
        let workload = try XCTUnwrap(trend.rows.first { $0.metric == .workload })

        XCTAssertEqual(workload.perWeek[0], 0)
        XCTAssertEqual(workload.perWeek[1], 1)
        XCTAssertNil(workload.perWeek[2], "a week with no answer stays empty")
        XCTAssertNil(trend.rows.first { $0.metric == .pump }, "a metric never answered has no row")
    }

    func testRenameTrimsAndIgnoresEmptyNames() throws {
        let (store, meso) = try startedStore(benchDay)

        store.rename(meso, to: "  Spring Block  ")
        XCTAssertEqual(meso.name, "Spring Block")

        store.rename(meso, to: "   ")
        XCTAssertEqual(meso.name, "Spring Block")
    }
}
