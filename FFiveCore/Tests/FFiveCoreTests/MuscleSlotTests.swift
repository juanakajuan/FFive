import XCTest

@testable import FFiveCore

final class MuscleSlotTests: XCTestCase {
    func listing(_ name: String, _ muscle: Muscle = .chest, _ equipment: Equipment = .barbell) -> ExerciseListing {
        let info = ExerciseInfo(name: name, muscle: muscle, equipment: equipment, repRange: 8...12, cue: nil)
        return ExerciseListing(id: info.id, name: name, muscle: muscle, info: info, isCustom: false, isHidden: false)
    }

    func draft(_ days: [[MesoDraft.Slot]]) -> MesoDraft {
        var draft = MesoDraft(template: nil)
        draft.days = days.enumerated().map { MesoDraft.Day(name: "Day \($0.offset + 1)", slots: $0.element) }
        return draft
    }

    func names(_ draft: MesoDraft) -> [[String?]] { draft.days.map { $0.slots.map(\.exercise) } }

    let everything = Set(Equipment.allCases)

    func testAnEmptySlotBlocksStarting() {
        var plan = draft([[.init(exercise: "Bench Press", muscle: .chest), .init(muscle: .back)]])
        XCTAssertFalse(plan.isStartable)
        plan.days[0].slots[1].exercise = "Pull-Up"
        XCTAssertTrue(plan.isStartable)
    }

    func testAutofillNeverRepeatsAnExerciseWithinADay() {
        let listings = ["Bench Press", "Cable Fly", "Dip"].map { listing($0) }
        var plan = draft([
            [.init(exercise: "Cable Fly", muscle: .chest), .init(muscle: .chest), .init(muscle: .chest)],
            [.init(muscle: .chest)],
        ])
        plan.autofill(from: listings, equipment: everything, lastPerformed: [:])
        XCTAssertEqual(names(plan), [["Cable Fly", "Bench Press", "Dip"], ["Bench Press"]])
        XCTAssertTrue(plan.isStartable)
    }

    func testAutofillPicksTheMuscleInYourEquipmentAndLeavesASlotEmptyWhenNothingIsLeft() {
        let listings = [
            listing("Bench Press", .chest, .barbell), listing("Machine Press", .chest, .machine),
            listing("Barbell Row", .back, .barbell),
        ]
        var plan = draft([[.init(muscle: .back), .init(muscle: .chest), .init(muscle: .chest)]])
        plan.autofill(from: listings, equipment: [.barbell], lastPerformed: [:])
        XCTAssertEqual(names(plan), [["Barbell Row", "Bench Press", nil]])
        XCTAssertFalse(plan.isStartable)
    }

    func testAutofillPrefersTheMostRecentlyDoneExercise() {
        let listings = ["Bench Press", "Dip"].map { listing($0) }
        var plan = draft([[.init(muscle: .chest)]])
        plan.autofill(
            from: listings, equipment: everything, lastPerformed: [ExerciseID(folding: "Dip"): .now])
        XCTAssertEqual(names(plan), [["Dip"]])
    }

    func testClearEmptiesEverySlotAndKeepsTheMuscles() {
        var plan = draft([
            [.init(exercise: "Bench Press", muscle: .chest), .init(muscle: .back)],
            [.init(exercise: "Squat", muscle: .quads)],
        ])
        plan.clearExercises()
        XCTAssertEqual(names(plan), [[nil, nil], [nil]])
        XCTAssertEqual(plan.days.map { $0.slots.map(\.muscle) }, [[.chest, .back], [.quads]])
    }
}
