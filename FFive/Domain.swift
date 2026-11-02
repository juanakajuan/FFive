import Foundation

// Pure domain types. Foundation only, so scripts/check-engine.sh can compile this file with swiftc.

enum WeightUnit: String, CaseIterable, Identifiable {
    case lb, kg
    var id: String { rawValue }
    var label: String {
        switch self {
        case .lb: "Pounds"
        case .kg: "Kilograms"
        }
    }
}

/// Weekly working-set landmarks for one muscle.
/// mv = maintenance, mev = minimum effective, mav = most productive range, mrv = maximum recoverable.
struct VolumeLandmarks: Equatable {
    let mv: Int
    let mev: Int
    let mav: ClosedRange<Int>
    let mrv: Int
}

enum Muscle: String, CaseIterable, Identifiable, Codable {
    case chest, back, quads, hamstrings, glutes
    case sideDelts, rearDelts, frontDelts
    case biceps, triceps, calves, traps, forearms, abs

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chest: "Chest"
        case .back: "Back"
        case .quads: "Quads"
        case .hamstrings: "Hamstrings"
        case .glutes: "Glutes"
        case .sideDelts: "Side Delts"
        case .rearDelts: "Rear Delts"
        case .frontDelts: "Front Delts"
        case .biceps: "Biceps"
        case .triceps: "Triceps"
        case .calves: "Calves"
        case .traps: "Traps"
        case .forearms: "Forearms"
        case .abs: "Abs"
        }
    }

    /// Population starting estimates in sets per week for an intermediate lifter.
    /// Individual landmarks vary and drift with training age; the feedback loop is what finds yours.
    var landmarks: VolumeLandmarks {
        switch self {
        case .chest: VolumeLandmarks(mv: 8, mev: 10, mav: 12...20, mrv: 22)
        case .back: VolumeLandmarks(mv: 8, mev: 10, mav: 14...22, mrv: 25)
        case .quads: VolumeLandmarks(mv: 6, mev: 8, mav: 12...18, mrv: 20)
        case .hamstrings: VolumeLandmarks(mv: 3, mev: 4, mav: 10...16, mrv: 20)
        case .glutes: VolumeLandmarks(mv: 0, mev: 0, mav: 4...12, mrv: 16)
        case .sideDelts: VolumeLandmarks(mv: 0, mev: 8, mav: 16...22, mrv: 26)
        case .rearDelts: VolumeLandmarks(mv: 0, mev: 6, mav: 12...18, mrv: 22)
        case .frontDelts: VolumeLandmarks(mv: 0, mev: 0, mav: 6...8, mrv: 12)
        case .biceps: VolumeLandmarks(mv: 5, mev: 8, mav: 14...20, mrv: 26)
        case .triceps: VolumeLandmarks(mv: 4, mev: 6, mav: 10...14, mrv: 18)
        case .calves: VolumeLandmarks(mv: 6, mev: 8, mav: 12...16, mrv: 20)
        case .traps: VolumeLandmarks(mv: 0, mev: 0, mav: 12...20, mrv: 26)
        case .forearms: VolumeLandmarks(mv: 0, mev: 2, mav: 6...12, mrv: 20)
        case .abs: VolumeLandmarks(mv: 0, mev: 0, mav: 16...20, mrv: 25)
        }
    }
}

enum Equipment: String, CaseIterable, Codable {
    case barbell, dumbbell, cable, machine, smith, bodyweight

    var displayName: String { rawValue == "smith" ? "Smith Machine" : rawValue.capitalized }

    /// Smallest sensible jump in load for this implement.
    func increment(_ unit: WeightUnit) -> Double {
        switch (self, unit) {
        case (.dumbbell, .lb): 5
        case (.dumbbell, .kg): 2
        case (.bodyweight, _): 0
        case (_, .lb): 5
        case (_, .kg): 2.5
        }
    }
}

struct ExerciseInfo: Identifiable, Hashable {
    let name: String
    let muscle: Muscle
    let equipment: Equipment
    let repRange: ClosedRange<Int>
    /// One-line technique or stimulus-to-fatigue cue shown in the session.
    let cue: String

    var id: String { name }
}

// MARK: - Session feedback

enum Soreness: Int, CaseIterable, Codable {
    case never, healedEarly, healedOnTime, stillSore
    var label: String {
        switch self {
        case .never: "Never got sore"
        case .healedEarly: "Healed a while ago"
        case .healedOnTime: "Healed just in time"
        case .stillSore: "Still sore"
        }
    }
}

enum Pump: Int, CaseIterable, Codable {
    case low, moderate, great
    var label: String { ["Low", "Moderate", "Great"][rawValue] }
}

enum Workload: Int, CaseIterable, Codable {
    case easy, good, hard, tooMuch
    var label: String { ["Easy", "Pretty good", "Pushed my limits", "Too much"][rawValue] }
}

enum JointPain: Int, CaseIterable, Codable {
    case none, low, moderate, severe
    var label: String { ["None", "Low", "Moderate", "A lot"][rawValue] }
}

/// What the lifter reported for one muscle in one session.
/// Soreness is reported at the start of the next session that trains the muscle, then written back here.
struct MuscleFeedback: Equatable, Codable {
    var soreness: Soreness?
    var pump: Pump?
    var workload: Workload?
    var jointPain: JointPain?
}

// MARK: - Program templates

struct TemplateSlot: Hashable {
    let muscle: Muscle
    let exercise: String
}

struct TemplateDay: Hashable {
    let name: String
    let slots: [TemplateSlot]
}

struct ProgramTemplate: Identifiable, Hashable {
    let name: String
    let summary: String
    let days: [TemplateDay]
    var id: String { name }
}
