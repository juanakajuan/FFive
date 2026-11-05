import SwiftData
import XCTest
@testable import FFiveCore

@MainActor
final class CatalogTests: XCTestCase {
    /// Finishes a quick workout with one exercise logged at `weight` x `reps`, through the store only.
    @discardableResult
    func finishedSession(_ store: Store, _ name: String, muscle: Muscle, weight: Double, reps: Int, at start: Date) -> Exercise {
        let workout = store.startQuickWorkout()
        workout.startDate = start
        store.addExercise(named: name, muscle: muscle, to: workout)
        let exercise = workout.exercises[0]
        for set in exercise.sets {
            set.weight = weight
            set.reps = reps
            store.log(set, done: true)
        }
        store.finish(workout)
        return exercise
    }

    func testCaseVariantsShareHistory() throws {
        XCTAssertEqual(ExerciseID(folding: "  bench  press "), ExerciseID(folding: "Bench Press"), "whitespace folds")
        XCTAssertEqual(ExerciseID(folding: "Bénch Prèss"), ExerciseID(folding: "Bench Press"), "diacritics fold")

        let store = Store(inMemory: true)
        let t0 = Date(timeIntervalSince1970: 1_800_000_000)
        let first = finishedSession(store, "Bench Press", muscle: .chest, weight: 100, reps: 8, at: t0)
        let later = finishedSession(store, "bench press", muscle: .chest, weight: 90, reps: 8, at: t0 + 86_400)

        XCTAssertEqual(first.key, later.key, "both spellings share one key")
        XCTAssertEqual(PlanningSnapshot(context: store.context).latestOneRepMax(of: ExerciseID(folding: "BENCH PRESS")),
                       Progression.estimatedOneRepMax(weight: 90, reps: 8, rir: 0), "planning reads the later row's 1RM")
        XCTAssertEqual(store.lastFinishedExercise(ExerciseID(folding: "Bench Press"))?.name, "bench press",
                       "the last time it was done is the lowercase row")
    }

    func testEveryTemplateSlotResolves() {
        XCTAssertEqual(ExerciseCatalog.byID.count, ExerciseCatalog.all.count, "no two catalog names fold to one key")
        for template in ExerciseCatalog.templates {
            for day in template.days {
                XCTAssertEqual(day.slots.count, day.exerciseNames.count, "\(template.name), \(day.name) dropped a slot")
                for name in day.exerciseNames {
                    XCTAssertNotNil(ExerciseCatalog.resolve(name), "\(template.name), \(day.name): \(name) is not in the catalog")
                }
            }
        }
    }
}
