import SwiftData
import XCTest

@testable import FFiveCore

@MainActor
final class DeleteAllDataTests: XCTestCase {
    let suite = "DeleteAllDataTests-\(UUID().uuidString)"

    override func tearDown() {
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
    }

    func count<Model: PersistentModel>(_: Model.Type, in store: Store) -> Int {
        (try? store.context.fetchCount(FetchDescriptor<Model>())) ?? -1
    }

    func counts(in store: Store) -> [String: Int] {
        Dictionary(uniqueKeysWithValues: AppStore.models.map { ("\($0)", count($0, in: store)) })
    }

    /// A store holding at least one record of every model, with every setting changed from its default.
    func filledStore() throws -> Store {
        let settings = Settings(defaults: try XCTUnwrap(UserDefaults(suiteName: suite)))
        let store = Store(inMemory: true, settings: settings)
        var draft = MesoDraft(template: nil)
        draft.days = [.init(name: "Push", slots: [.init(exercise: "Bench Press", muscle: .chest)])]
        try store.startMesocycle(draft)
        let meso = try XCTUnwrap(store.context.fetch(Mesocycle.active).first)
        store.addNote("Sleep has been poor", to: meso)
        let session = store.buildSession(meso, at: SessionKey(week: 0, dayIndex: 0))
        let bench = session.sortedExercises[0]
        store.log(bench.sortedSets[0], done: true)
        store.updateFeedback(for: .chest, in: session) { $0.pump = .great }
        store.setNote("Shoulder felt fine", on: bench)
        store.pinNote(on: bench)
        try store.saveCustomExercise(CustomExerciseDraft(name: "Garage Sled Push", muscle: .quads))
        store.saveTemplate(from: meso, named: "Mine")
        store.startQuickWorkout()

        settings.weightUnit = .kg
        settings.autoMatchWeights = false
        settings.appearance = .light
        settings.toggle(.barbell)
        settings.hiddenExercises = [ExerciseID(folding: "Bench Press")]
        settings.dismiss(CoachingTip.allCases[0])
        settings.changelogSeenVersion = "1.0"
        return store
    }

    func testDeletesEveryRecordOfEveryModel() throws {
        let store = try filledStore()
        XCTAssertNil(store.failure)
        for (model, count) in counts(in: store) {
            XCTAssertGreaterThan(count, 0, "the test fills \(model), so the wipe is proven to reach it")
        }

        store.deleteAllData()

        XCTAssertNil(store.failure)
        XCTAssertFalse(store.context.hasChanges, "the deletes are saved, which is what sends them to iCloud")
        XCTAssertEqual(counts(in: store).filter { $0.value != 0 }, [:], "no record of any model is left")
        XCTAssertFalse(store.hasTrainingHistory, "the app opens as a fresh install does")
    }

    func testResetsEverySettingAndLeavesNothingStored() throws {
        let store = try filledStore()
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))

        store.deleteAllData()

        let settings = store.settings
        XCTAssertEqual(settings.weightUnit, .lb)
        XCTAssertTrue(settings.autoMatchWeights)
        XCTAssertEqual(settings.appearance, .dark)
        XCTAssertEqual(settings.equipment, Set(Equipment.allCases))
        XCTAssertEqual(settings.hiddenExercises, [])
        XCTAssertEqual(settings.dismissedTips, [])
        XCTAssertNil(settings.changelogSeenVersion)
        XCTAssertEqual(
            defaults.persistentDomain(forName: suite)?.keys.sorted() ?? [], [],
            "every stored key is gone, including one a later setting adds")
    }

    func testBuiltInCatalogStillPlansAfterTheWipe() throws {
        let store = try filledStore()
        store.deleteAllData()

        let template = try XCTUnwrap(ExerciseCatalog.templates.first)
        try store.startMesocycle(MesoDraft(template: template))
        let meso = try XCTUnwrap(store.context.fetch(Mesocycle.active).first)
        let session = store.buildSession(meso, at: SessionKey(week: 0, dayIndex: 0))

        XCTAssertFalse(session.sortedExercises.isEmpty, "a built-in template still builds a session")
        XCTAssertNil(store.failure)
        XCTAssertFalse(try store.exportJSON().isEmpty, "export still runs")
    }
}
