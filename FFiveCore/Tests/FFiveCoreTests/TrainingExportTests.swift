import SwiftData
import XCTest

@testable import FFiveCore

@MainActor
final class TrainingExportTests: XCTestCase {
    func decode(_ data: Data) throws -> TrainingExport {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(TrainingExport.self, from: data)
    }

    func testExportCarriesEveryKindOfRecord() throws {
        let store = Store(inMemory: true)
        var draft = MesoDraft(template: nil)
        draft.days = [.init(name: "Push", slots: [.init(exercise: "Bench Press", muscle: .chest)])]
        try store.startMesocycle(draft)
        let meso = try XCTUnwrap(store.context.fetch(Mesocycle.active).first)
        let session = store.buildSession(meso, at: SessionKey(week: 0, dayIndex: 0))
        let bench = session.sortedExercises[0]
        store.setWeight(185, of: bench.sortedSets[0], carryingTo: [])
        store.setReps(8, of: bench.sortedSets[0])
        store.log(bench.sortedSets[0], done: true)
        store.updateFeedback(for: .chest, in: session) { $0.pump = .great }
        store.setNote("Shoulder felt fine", on: bench)
        store.pinNote(on: bench)
        store.finish(session)

        let quick = store.startQuickWorkout()
        store.addExercise(named: "Landmine Press", muscle: .frontDelts, to: quick)
        store.log(quick.sortedExercises[0].sortedSets[0], done: true)
        store.finish(quick)
        store.saveTemplate(from: meso, named: "Mine")

        XCTAssertNil(store.failure)

        let export = try decode(store.exportJSON())

        XCTAssertEqual(export.version, 1)
        XCTAssertEqual(export.weightUnit, "lb")
        let exportedMeso = try XCTUnwrap(export.mesocycles.first)
        XCTAssertEqual(
            exportedMeso.days, [.init(name: "Push", slots: [.init(exercise: "Bench Press", muscle: "chest")])])
        let exportedSession = try XCTUnwrap(exportedMeso.workouts.first)
        XCTAssertEqual(exportedSession.week, 0)
        XCTAssertNotNil(exportedSession.endDate)
        let firstSet = try XCTUnwrap(exportedSession.exercises.first?.sets.first)
        XCTAssertEqual(firstSet.status, "done")
        XCTAssertEqual(firstSet.weight, 185)
        XCTAssertEqual(firstSet.reps, 8)
        XCTAssertEqual(exportedSession.feedback, [.init(muscle: "chest", pump: "great")])
        XCTAssertEqual(export.workouts.map { $0.exercises.map(\.name) }, [["Landmine Press"]], "free-form sessions")
        XCTAssertEqual(
            export.customExercises, [.init(name: "Landmine Press", muscle: "frontDelts")],
            "\(quick.exercises.map { ($0.key.rawValue, $0.info?.name ?? "nil", $0.muscleRaw ?? "nil", $0.workout === quick) })"
        )
        XCTAssertEqual(export.templates.map(\.name), ["Mine"])
        XCTAssertEqual(export.pinnedNotes, [.init(exercise: "Bench Press", text: "Shoulder felt fine")])
    }

    func testEmptyStoreExportsEmptyLists() throws {
        let export = try decode(Store(inMemory: true).exportJSON())

        XCTAssertTrue(export.mesocycles.isEmpty)
        XCTAssertTrue(export.workouts.isEmpty)
        XCTAssertTrue(export.customExercises.isEmpty)
    }
}
