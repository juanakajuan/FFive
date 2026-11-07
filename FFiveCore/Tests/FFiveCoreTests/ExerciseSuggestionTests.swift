import XCTest

@testable import FFiveCore

final class ExerciseSuggestionTests: XCTestCase {
    func listing(
        _ name: String, _ muscle: Muscle = .chest, _ equipment: Equipment = .barbell, custom: Bool = false,
        hidden: Bool = false
    ) -> ExerciseListing {
        let info = ExerciseInfo(name: name, muscle: muscle, equipment: equipment, repRange: 8...12, cue: nil)
        return ExerciseListing(id: info.id, name: name, muscle: muscle, info: info, isCustom: custom, isHidden: hidden)
    }

    func cycle(
        _ listings: [ExerciseListing], muscle: Muscle = .chest, equipment: Set<Equipment> = Set(Equipment.allCases),
        lastPerformed: [ExerciseID: Date] = [:], steps: Int
    ) -> [String] {
        var current: ExerciseID?
        var names: [String] = []
        for _ in 0..<steps {
            guard
                let next = ExerciseListing.suggestion(
                    after: current, in: listings, muscle: muscle, equipment: equipment, lastPerformed: lastPerformed)
            else { break }
            names.append(next.name)
            current = next.id
        }
        return names
    }

    func testPrefersMostRecentlyDoneThenCyclesByName() {
        let t0 = Date(timeIntervalSince1970: 1_800_000_000)
        let listings = ["Bench Press", "Cable Fly", "Dip", "Pec Deck"].map { listing($0) }
        let done = [ExerciseID(folding: "Dip"): t0, ExerciseID(folding: "Pec Deck"): t0 + 86_400]
        XCTAssertEqual(
            cycle(listings, lastPerformed: done, steps: 5),
            ["Pec Deck", "Dip", "Bench Press", "Cable Fly", "Pec Deck"])
    }

    func testOnlySuggestsTheMuscleInAvailableEquipment() {
        let listings = [
            listing("Bench Press", .chest, .barbell),
            listing("Machine Press", .chest, .machine),
            listing("Squat", .quads, .machine),
            listing("Hidden Fly", .chest, .machine, hidden: true),
            listing("Garage Press", .chest, .barbell, custom: true),
        ]
        XCTAssertEqual(
            cycle(listings, equipment: [.machine], steps: 3), ["Garage Press", "Machine Press", "Garage Press"])
    }

    func testNilWhenNothingFits() {
        XCTAssertNil(
            ExerciseListing.suggestion(
                after: nil, in: [listing("Squat", .quads)], muscle: .chest, equipment: [.barbell], lastPerformed: [:]))
    }

    func testStartsOverWhenCurrentNoLongerFits() {
        let listings = [listing("Bench Press"), listing("Dip")]
        XCTAssertEqual(
            ExerciseListing.suggestion(
                after: ExerciseID(folding: "Squat"), in: listings, muscle: .chest, equipment: [.barbell],
                lastPerformed: [:])?.name,
            "Bench Press")
    }
}
