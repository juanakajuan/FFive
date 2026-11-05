import Foundation
import XCTest

@testable import FFiveCore

@MainActor
final class SettingsTests: XCTestCase {
    let suite = "SettingsTests-\(UUID().uuidString)"

    override func tearDown() {
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
    }

    func testWeightUnitPersistsUnderTheKeyEarlierBuildsWrote() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        XCTAssertEqual(Settings(defaults: defaults).weightUnit, .lb, "a fresh install trains in pounds")

        defaults.set("kg", forKey: "weightUnit")
        XCTAssertEqual(
            Settings(defaults: defaults).weightUnit, .kg,
            "an @AppStorage(\"weightUnit\") value from an earlier build is read")

        let settings = Settings(defaults: defaults)
        settings.weightUnit = .lb
        XCTAssertEqual(defaults.string(forKey: "weightUnit"), "lb", "a change is written under the same key at once")
        XCTAssertEqual(Settings(defaults: defaults).weightUnit, .lb, "and read back on the next launch")
    }

    func testStorePlansInTheSettingsUnit() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.set("kg", forKey: "weightUnit")
        let store = Store(inMemory: true, settings: Settings(defaults: defaults))
        let history = store.startQuickWorkout()
        store.addExercise(named: "Bench Press", muscle: .chest, to: history)
        history.exercises[0].sets[0].weight = 61
        history.exercises[0].sets[0].reps = 8
        store.log(history.exercises[0].sets[0], done: true)
        store.finish(history)

        var draft = MesoDraft(template: nil)
        draft.days = [.init(name: "A", slots: [.init(exercise: "Bench Press", muscle: .chest)])]
        try store.startMesocycle(draft)
        let meso = try XCTUnwrap(store.context.fetch(Mesocycle.active).first)
        let session = store.buildSession(meso, at: SessionKey(week: 0, dayIndex: 0))
        let load = try XCTUnwrap(session.sortedExercises[0].sortedSets[0].targetWeight)

        XCTAssertEqual(
            load.truncatingRemainder(dividingBy: 2.5), 0, "a kilogram lifter's barbell target lands on a 2.5 kg jump")
        XCTAssertNotEqual(
            load.truncatingRemainder(dividingBy: 5), 0, "and not on the 5 lb jump a pound lifter would get")
    }
}
