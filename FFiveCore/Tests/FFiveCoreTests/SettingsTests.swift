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

    func testAutoMatchWeightsDefaultsOnAndPersistsOff() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        XCTAssertTrue(Settings(defaults: defaults).autoMatchWeights)

        Settings(defaults: defaults).autoMatchWeights = false
        XCTAssertFalse(Settings(defaults: defaults).autoMatchWeights)
    }

    func testAppearanceDefaultsDarkAndPersists() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        XCTAssertEqual(Settings(defaults: defaults).appearance, .dark, "an upgrade keeps the dark look it had")

        Settings(defaults: defaults).appearance = .light
        XCTAssertEqual(Settings(defaults: defaults).appearance, .light, "a choice is read back on the next launch")

        defaults.set("sepia", forKey: "appearance")
        XCTAssertEqual(Settings(defaults: defaults).appearance, .dark, "an unknown value falls back to dark")
    }

    func testEquipmentDefaultsToAllAndDoesNotFilter() throws {
        let settings = Settings(defaults: try XCTUnwrap(UserDefaults(suiteName: suite)))
        XCTAssertEqual(settings.equipment, Set(Equipment.allCases), "a fresh install has every kind of equipment")
        XCTAssertFalse(settings.filtersEquipment, "so nothing is hidden")
    }

    func testEquipmentChoicePersistsAcrossLaunches() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let settings = Settings(defaults: defaults)
        settings.toggle(.barbell)

        let reloaded = Settings(defaults: defaults)
        XCTAssertFalse(reloaded.equipment.contains(.barbell), "a toggled-off item stays off on the next launch")
        XCTAssertEqual(reloaded.equipment.count, Equipment.allCases.count - 1)
        XCTAssertTrue(reloaded.filtersEquipment)

        reloaded.toggle(.barbell)
        XCTAssertFalse(Settings(defaults: defaults).filtersEquipment, "toggling it back on restores the full set")
    }

    func testEquipmentKeepsTheLastItem() throws {
        let settings = Settings(defaults: try XCTUnwrap(UserDefaults(suiteName: suite)))
        for item in Equipment.allCases { settings.toggle(item) }
        XCTAssertEqual(settings.equipment.count, 1, "the last remaining item cannot be removed")
        let last = try XCTUnwrap(settings.equipment.first)
        settings.toggle(last)
        XCTAssertEqual(settings.equipment, [last])
    }

    func testUnreadableEquipmentFallsBackToAll() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.set(["jetpack", "trampoline"], forKey: "equipment")
        XCTAssertEqual(Settings(defaults: defaults).equipment, Set(Equipment.allCases), "unknown values count as none")

        defaults.set([String](), forKey: "equipment")
        XCTAssertEqual(Settings(defaults: defaults).equipment, Set(Equipment.allCases), "an empty list falls back too")

        defaults.set(["dumbbell", "jetpack"], forKey: "equipment")
        XCTAssertEqual(Settings(defaults: defaults).equipment, [.dumbbell], "unknown values are dropped, known kept")
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
