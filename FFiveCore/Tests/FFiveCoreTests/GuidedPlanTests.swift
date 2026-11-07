import XCTest

@testable import FFiveCore

final class GuidedPlanTests: XCTestCase {
    func sessions(_ draft: MesoDraft) -> [Muscle: [Int]] {
        var result: [Muscle: [Int]] = [:]
        for (index, day) in draft.days.enumerated() {
            for slot in day.slots { result[slot.muscle, default: []].append(index) }
        }
        return result
    }

    func testEveryMuscleTrainsAsOftenAsItsPriorityAsks() {
        let priorities: [Muscle: MusclePriority] = [.chest: .emphasize, .sideDelts: .emphasize, .calves: .maintain]
        for days in MesoDraft.guidedDaysPerWeek {
            let draft = MesoDraft(daysPerWeek: days, priorities: priorities)
            XCTAssertEqual(draft.days.count, days)
            let trained = sessions(draft)
            XCTAssertEqual(Set(trained.keys), Set(Muscle.allCases), "every muscle is trained")
            XCTAssertEqual(trained[.chest]?.count, min(days, 3))
            XCTAssertEqual(trained[.back]?.count, 2)
            XCTAssertEqual(trained[.calves]?.count, 1)
            XCTAssertEqual(trained[.abs]?.count, 1, "abs default to maintain")
            for (muscle, dayIndexes) in trained {
                XCTAssertEqual(Set(dayIndexes).count, dayIndexes.count, "\(muscle) trains once per day at most")
            }
        }
    }

    func testAMusclesSessionsAreSpacedThroughTheWeek() {
        for days in 4...6 {
            let draft = MesoDraft(daysPerWeek: days, priorities: [:])
            for (muscle, dayIndexes) in sessions(draft) where dayIndexes.count == 2 {
                let gap = abs(dayIndexes[1] - dayIndexes[0])
                XCTAssertGreaterThanOrEqual(min(gap, days - gap), 2, "\(muscle) on \(days) days: \(dayIndexes)")
            }
        }
    }

    func testDaysHoldAboutTheSameNumberOfMuscles() {
        for days in MesoDraft.guidedDaysPerWeek {
            let even = MesoDraft(daysPerWeek: days, priorities: [:]).days.map(\.slots.count)
            XCTAssertLessThanOrEqual(even.max()! - even.min()!, 1, "\(days) days: \(even)")
            let emphasized = MesoDraft(daysPerWeek: days, priorities: [.quads: .emphasize]).days.map(\.slots.count)
            XCTAssertLessThanOrEqual(emphasized.max()! - emphasized.min()!, 2, "\(days) days: \(emphasized)")
        }
    }

    func testSlotsAreMusclesWaitingForAnExerciseWithEmphasizedOnesFirst() {
        let draft = MesoDraft(daysPerWeek: 3, priorities: [.biceps: .emphasize])
        XCTAssertTrue(draft.days.allSatisfy { $0.slots.allSatisfy { $0.exercise == nil } })
        XCTAssertTrue(draft.hasEmptySlot)
        for day in draft.days where day.slots.contains(where: { $0.muscle == .biceps }) {
            XCTAssertEqual(day.slots.first?.muscle, .biceps)
        }
        XCTAssertEqual(draft.priorities[.biceps], .emphasize)
        XCTAssertEqual(draft.priorities[.chest], .normal)
        XCTAssertEqual(draft.priorities[.traps], .maintain)
        XCTAssertEqual(draft.name, "3-Day Plan")
    }

    func testFourDaysSplitIntoUpperAndLower() {
        let draft = MesoDraft(daysPerWeek: 4, priorities: [:])
        XCTAssertEqual(draft.days.map(\.name), ["Upper A", "Lower A", "Upper B", "Lower B"])
        XCTAssertEqual(draft.days[0].slots.map(\.muscle), [.chest, .back, .sideDelts, .rearDelts, .biceps, .triceps])
    }

    func testDaysOutsideTheRangeAreClamped() {
        XCTAssertEqual(MesoDraft(daysPerWeek: 9, priorities: [:]).days.count, 6)
        XCTAssertEqual(MesoDraft(daysPerWeek: 0, priorities: [:]).days.count, 2)
    }

    func testAutofillFillsAGuidedPlan() {
        var draft = MesoDraft(daysPerWeek: 4, priorities: [:])
        let listings = ExerciseCatalog.all.map {
            ExerciseListing(id: $0.id, name: $0.name, muscle: $0.muscle, info: $0, isCustom: false, isHidden: false)
        }
        draft.autofill(from: listings, equipment: Set(Equipment.allCases), lastPerformed: [:])
        XCTAssertTrue(draft.isStartable)
    }
}
