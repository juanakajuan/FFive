import SwiftData
import XCTest

@testable import FFiveCore

@MainActor
final class CustomTemplateTests: XCTestCase {
    func templates(_ store: Store) throws -> [ProgramTemplate] {
        try store.context.fetch(CustomTemplate.all).map(\.template)
    }

    func testDraftSavesItsDaysAndSkipsEmptyOnes() throws {
        let store = Store(inMemory: true)
        var draft = MesoDraft(template: nil)
        draft.days = [
            .init(name: "Push", slots: [.init(exercise: "Bench Press", muscle: .chest)]),
            .init(name: "Empty", slots: []),
            .init(name: "Pull", slots: [.init(exercise: "Barbell Row", muscle: .back)]),
        ]

        store.saveTemplate(from: draft, named: "  My Split ")

        let saved = try XCTUnwrap(templates(store).first)
        XCTAssertEqual(saved.name, "My Split")
        XCTAssertEqual(saved.days.map(\.name), ["Push", "Pull"])
        XCTAssertEqual(saved.days[0].slots, [TemplateSlot(muscle: .chest, exercise: "Bench Press")])
        XCTAssertNil(store.failure)
    }

    func testSavedTemplateRebuildsTheSameDraft() throws {
        let store = Store(inMemory: true)
        let source = MesoDraft(template: ExerciseCatalog.templates[1])
        store.saveTemplate(from: source, named: "Copy")

        let rebuilt = MesoDraft(template: try XCTUnwrap(templates(store).first))

        XCTAssertEqual(rebuilt.name, "Copy")
        XCTAssertEqual(rebuilt.days.map(\.name), source.days.map(\.name))
        XCTAssertEqual(
            rebuilt.days.map { $0.slots.map(\.exercise) }, source.days.map { $0.slots.map(\.exercise) })
    }

    func testMesocycleSavesItsCurrentLayout() throws {
        let store = Store(inMemory: true)
        try store.startMesocycle(MesoDraft(template: ExerciseCatalog.templates[0]))
        let meso = try XCTUnwrap(store.context.fetch(Mesocycle.active).first)
        meso.sortedDays[0].name = "Legs"

        store.saveTemplate(from: meso, named: "")

        let saved = try XCTUnwrap(templates(store).first)
        XCTAssertEqual(
            saved.name, "\(ExerciseCatalog.templates[0].name) 2", "a blank name falls back to the block's, kept unique")
        XCTAssertEqual(saved.days.map(\.name), meso.dayNames)
        XCTAssertEqual(saved.days.map(\.slots.count), meso.sortedDays.map(\.slots.count))
    }

    func testNamesStayUniqueAcrossBuiltInAndCustom() throws {
        let store = Store(inMemory: true)
        let draft = MesoDraft(template: ExerciseCatalog.templates[0])

        store.saveTemplate(from: draft, named: "PPL")
        store.saveTemplate(from: draft, named: "ppl")
        store.saveTemplate(from: draft, named: "Upper/Lower, 4 Days")

        XCTAssertEqual(try templates(store).map(\.name).sorted(), ["PPL", "Upper/Lower, 4 Days 2", "ppl 2"])
    }

    func testCopyKeepsTheDaysUnderAFreeCopyName() throws {
        let store = Store(inMemory: true)
        let builtIn = ExerciseCatalog.templates[0]

        let first = store.copyTemplate(builtIn)
        let second = store.copyTemplate(builtIn)
        let ofCustom = store.copyTemplate(first.template)

        XCTAssertEqual(first.name, "\(builtIn.name) copy")
        XCTAssertEqual(second.name, "\(builtIn.name) copy 2", "a taken copy name gets the next free number")
        XCTAssertEqual(ofCustom.name, "\(builtIn.name) copy copy")
        XCTAssertEqual(first.template.days.map(\.name), builtIn.days.map(\.name))
        XCTAssertEqual(first.template.days.map(\.slots), builtIn.days.map(\.slots))
        XCTAssertEqual(ofCustom.template.days, first.template.days)
        XCTAssertEqual(try templates(store).count, 3)
        XCTAssertNil(store.failure)
    }

    func testRenameAndDelete() throws {
        let store = Store(inMemory: true)
        store.saveTemplate(from: MesoDraft(template: ExerciseCatalog.templates[0]), named: "A")
        store.saveTemplate(from: MesoDraft(template: ExerciseCatalog.templates[0]), named: "B")
        let all = try store.context.fetch(CustomTemplate.all)

        store.rename(all[0], to: "   ")
        XCTAssertEqual(all[0].name, "A", "a blank rename is ignored")
        store.rename(all[0], to: "B")
        XCTAssertEqual(all[0].name, "B 2")
        store.rename(all[1], to: "B")
        XCTAssertEqual(all[1].name, "B", "renaming to its own name keeps it")

        store.delete(all[1])
        XCTAssertEqual(try templates(store).map(\.name), ["B 2"])
        XCTAssertNil(store.failure)
    }

    func testDraftWithNoExercisesSavesNothing() throws {
        let store = Store(inMemory: true)
        store.saveTemplate(from: MesoDraft(template: nil), named: "Empty")
        XCTAssertTrue(try templates(store).isEmpty)
    }

    func testUpdateReplacesTheDaysAndKeepsTheName() throws {
        let store = Store(inMemory: true)
        store.saveTemplate(from: MesoDraft(template: ExerciseCatalog.templates[0]), named: "Mine")
        let saved = try XCTUnwrap(store.context.fetch(CustomTemplate.all).first)
        var draft = MesoDraft(template: saved.template)
        draft.days = [.init(name: "Arms", slots: [.init(exercise: "Barbell Curl", muscle: .biceps)])]

        store.updateTemplate(saved, from: draft)

        XCTAssertEqual(saved.template.name, "Mine")
        XCTAssertEqual(saved.template.days.map(\.name), ["Arms"])
        XCTAssertEqual(saved.template.days[0].slots, [TemplateSlot(muscle: .biceps, exercise: "Barbell Curl")])

        draft.days = [.init(name: "Empty", slots: [])]
        store.updateTemplate(saved, from: draft)
        XCTAssertEqual(saved.template.days.map(\.name), ["Arms"], "an edit with no exercise keeps the old days")
    }

    func testWeeklyExercisesCountsEachMuscleMostFirst() {
        let template = ProgramTemplate(
            name: "T", emphasis: nil, summary: "",
            days: [
                TemplateDay(
                    name: "A", exerciseNames: [],
                    slots: [.init(muscle: .biceps, exercise: "x"), .init(muscle: .chest, exercise: "y")]),
                TemplateDay(name: "B", exerciseNames: [], slots: [.init(muscle: .biceps, exercise: "z")]),
                TemplateDay(name: "C", exerciseNames: [], slots: [.init(muscle: .back, exercise: "w")]),
            ])

        XCTAssertEqual(template.weeklyExercises.map(\.muscle), [.biceps, .chest, .back])
        XCTAssertEqual(template.weeklyExercises.map(\.count), [2, 1, 1])
    }
}
