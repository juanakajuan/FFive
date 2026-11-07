import SwiftData
import XCTest

@testable import FFiveCore

@MainActor
final class MesoCopyTests: XCTestCase {
    private let day: TimeInterval = 24 * 60 * 60

    func startedStore() throws -> (Store, Mesocycle) {
        let store = Store(inMemory: true)
        var draft = MesoDraft(template: nil)
        draft.name = "Push Pull"
        draft.accumulationWeeks = 5
        draft.priorities = [.chest: .emphasize]
        draft.days = [
            .init(
                name: "Push", weekday: .monday,
                slots: [.init(exercise: "Bench Press", muscle: .chest), .init(exercise: "Cable Fly", muscle: .chest)]),
            .init(name: "Pull", weekday: .thursday, slots: [.init(exercise: "Barbell Row", muscle: .back)]),
        ]
        try store.startMesocycle(draft)
        return (store, try XCTUnwrap(store.context.fetch(Mesocycle.active).first))
    }

    func finish(_ key: SessionKey, of meso: Mesocycle, in store: Store, weight: Double = 100, reps: Int = 8) {
        let workout = store.buildSession(meso, at: key)
        for set in workout.sortedExercises.flatMap(\.sortedSets) {
            set.weight = weight
            set.reps = reps
            store.log(set, done: true)
        }
        store.finish(workout)
    }

    func testCopyKeepsLengthPrioritiesDaysAndWeekdays() throws {
        let (store, meso) = try startedStore()

        let draft = withExtendedLifetime(store) { meso.copyDraft(week: 0) }

        XCTAssertEqual(draft.name, "Push Pull")
        XCTAssertEqual(draft.accumulationWeeks, 5)
        XCTAssertEqual(draft.priorities, [.chest: .emphasize], "normal muscles stay out of the map")
        XCTAssertEqual(draft.days.map(\.name), ["Push", "Pull"])
        XCTAssertEqual(draft.days.map(\.weekday), [.monday, .thursday])
        XCTAssertEqual(draft.days.map { $0.slots.map(\.exercise) }, [["Bench Press", "Cable Fly"], ["Barbell Row"]])
        XCTAssertEqual(meso.copyableWeeks, 0..<5, "the deload is not a source week")
    }

    func testCopyTakesTheExercisesTheSourceWeekTrained() throws {
        let (store, meso) = try startedStore()
        finish(SessionKey(week: 0, dayIndex: 0), of: meso, in: store)
        let push = store.buildSession(meso, at: SessionKey(week: 1, dayIndex: 0))
        store.swapExercise(push.sortedExercises[1], to: "Pec Deck", muscle: .chest)
        store.finish(push)

        XCTAssertEqual(meso.copyDraft(week: 0).days[0].slots.map(\.exercise), ["Bench Press", "Cable Fly"])
        XCTAssertEqual(
            meso.copyDraft(week: 1).days[0].slots.map(\.exercise), ["Bench Press", "Pec Deck"],
            "week 2 swapped the fly")
        XCTAssertEqual(
            meso.copyDraft(week: 1).days[1].slots.map(\.exercise), ["Barbell Row"],
            "a day not built that week falls back to its plan")
    }

    func testRecentBlockCarriesTheSourceWeeksLoggedSets() throws {
        let (store, meso) = try startedStore()
        finish(SessionKey(week: 0, dayIndex: 0), of: meso, in: store, weight: 135, reps: 9)
        let pull = store.buildSession(meso, at: SessionKey(week: 0, dayIndex: 1))
        let row = pull.sortedExercises[0].sortedSets
        row[0].weight = 155
        row[0].reps = 10
        store.log(row[0], done: true)
        store.skip(row[1], skipped: true)
        store.finish(pull)

        let draft = meso.copyDraft(week: 0, now: .now + 20 * day)

        let bench = try XCTUnwrap(draft.days[0].slots[0].startingTargets)
        XCTAssertFalse(bench.isEmpty)
        XCTAssertTrue(bench.allSatisfy { $0 == SetTarget(weight: 135, reps: 9) })
        XCTAssertEqual(
            draft.days[1].slots[0].startingTargets?.first, SetTarget(weight: 155, reps: 10),
            "a logged set gives its weight and reps")
        XCTAssertEqual(draft.days[1].slots[0].startingTargets?.count, row.count - 1, "the skipped set is dropped")
    }

    func testOldBlockStartsFresh() throws {
        let (store, meso) = try startedStore()
        finish(SessionKey(week: 0, dayIndex: 0), of: meso, in: store)

        XCTAssertTrue(meso.carriesLoads(now: .now + 20 * day))
        XCTAssertFalse(meso.carriesLoads(now: .now + 21 * day), "21 days is no longer recent")
        let draft = meso.copyDraft(week: 0, now: .now + 21 * day)
        XCTAssertNil(draft.days[0].slots[0].startingTargets)
        XCTAssertEqual(draft.days[0].slots.map(\.exercise), ["Bench Press", "Cable Fly"], "the layout still copies")
    }

    func testDeloadSessionsDoNotMakeABlockRecent() throws {
        let (store, meso) = try startedStore()
        XCTAssertNil(meso.lastAccumulationDate)
        let deload = store.buildSession(meso, at: SessionKey(week: 5, dayIndex: 0))
        store.logEntered(deload.sortedExercises[0].sortedSets[0])
        store.finish(deload)

        XCTAssertNil(meso.lastAccumulationDate)
        XCTAssertFalse(meso.carriesLoads())
    }

    func testSwappingACopiedExerciseDropsItsLoads() throws {
        let (store, meso) = try startedStore()
        finish(SessionKey(week: 0, dayIndex: 0), of: meso, in: store)
        var draft = meso.copyDraft(week: 0)
        XCTAssertNotNil(draft.days[0].slots[0].startingTargets)

        draft.days[0].slots[0].exercise = "Dumbbell Press"

        XCTAssertNil(draft.days[0].slots[0].startingTargets)
    }

    func testCopiedBlockStartsItsFirstWeekFromTheCarriedSets() throws {
        let (store, meso) = try startedStore()
        finish(SessionKey(week: 0, dayIndex: 0), of: meso, in: store, weight: 135, reps: 9)
        let benchSets = meso.workout(at: SessionKey(week: 0, dayIndex: 0))!.sortedExercises[0].sets.count
        let draft = meso.copyDraft(week: 0)
        store.endMesocycle(meso)

        try store.startMesocycle(draft)
        let copy = try XCTUnwrap(store.context.fetch(Mesocycle.active).first)
        let push = store.buildSession(copy, at: SessionKey(week: 0, dayIndex: 0))

        let bench = push.sortedExercises[0].sortedSets
        XCTAssertEqual(bench.count, benchSets, "the carried sets set the count")
        XCTAssertTrue(bench.allSatisfy { $0.targetWeight == 135 && $0.targetReps == 9 })
        XCTAssertTrue(bench.allSatisfy { $0.weight == 135 && $0.reps == 9 })
        let pull = store.buildSession(copy, at: SessionKey(week: 0, dayIndex: 1))
        XCTAssertNotEqual(
            pull.sortedExercises[0].sortedSets.first?.targetWeight, 135, "a day never logged plans fresh")
    }
}
