import Foundation

public enum WeightUnit: String, CaseIterable, Identifiable {
    case lb, kg
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .lb: "Pounds"
        case .kg: "Kilograms"
        }
    }
}

public enum Appearance: String, CaseIterable, Identifiable {
    case system, dark, light
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .system: "System"
        case .dark: "Dark"
        case .light: "Light"
        }
    }
}

/// Weekly working-set landmarks for one muscle.
/// mv = maintenance, mev = minimum effective, mav = most productive range, mrv = maximum recoverable.
public struct VolumeLandmarks: Equatable {
    public let mv: Int
    public let mev: Int
    public let mav: ClosedRange<Int>
    public let mrv: Int
}

public enum Muscle: String, CaseIterable, Identifiable, Codable {
    case chest, back, quads, hamstrings, glutes
    case sideDelts, rearDelts, frontDelts
    case biceps, triceps, calves, traps, forearms, abs

    public var id: String { rawValue }

    public var displayName: String {
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
    public var landmarks: VolumeLandmarks {
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

/// How a block trains one muscle. Emphasized muscles add sets faster, maintained ones start at maintenance volume
/// and never add sets, so recovery goes to the muscles being grown.
public enum MusclePriority: String, CaseIterable, Codable, Identifiable {
    case emphasize, normal, maintain

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .emphasize: "Emphasize"
        case .normal: "Normal"
        case .maintain: "Maintain"
        }
    }
}

public enum Equipment: String, CaseIterable, Codable {
    case barbell, dumbbell, cable, machine, smith, assistedMachine, bodyweightLoadable, bodyweightOnly

    public var displayName: String {
        switch self {
        case .barbell: "Barbell"
        case .dumbbell: "Dumbbell"
        case .cable: "Cable"
        case .machine: "Machine"
        case .smith: "Smith Machine"
        case .assistedMachine: "Assisted Machine"
        case .bodyweightLoadable: "Bodyweight Loadable"
        case .bodyweightOnly: "Bodyweight Only"
        }
    }

    /// Whether a logged weight is added to body weight, negative for assistance.
    var addsToBodyweight: Bool {
        switch self {
        case .assistedMachine, .bodyweightLoadable, .bodyweightOnly: true
        case .barbell, .dumbbell, .cable, .machine, .smith: false
        }
    }

    /// Smallest sensible jump in load for this implement. For a body lift it is the step of added load or shed
    /// assistance, and 0 when there is nothing to add, so progression adds reps.
    public func increment(_ unit: WeightUnit) -> Double {
        switch (self, unit) {
        case (.bodyweightOnly, _): 0
        case (.dumbbell, .lb): 5
        case (.dumbbell, .kg): 2
        case (_, .lb): 5
        case (_, .kg): 2.5
        }
    }
}

public struct ExerciseInfo: Identifiable, Hashable {
    public let id: ExerciseID
    public let name: String
    public let muscle: Muscle
    public let equipment: Equipment
    public let repRange: ClosedRange<Int>
    public let cue: String?

    init(name: String, muscle: Muscle, equipment: Equipment, repRange: ClosedRange<Int>, cue: String?) {
        id = ExerciseID(folding: name)
        self.name = name
        self.muscle = muscle
        self.equipment = equipment
        self.repRange = repRange
        self.cue = cue
    }
}

public enum Soreness: Int, CaseIterable, Codable {
    case never, healedEarly, healedOnTime, stillSore
    public var label: String {
        switch self {
        case .never: "Never got sore"
        case .healedEarly: "Healed a while ago"
        case .healedOnTime: "Healed just in time"
        case .stillSore: "Still sore"
        }
    }

    public var meaning: String {
        switch self {
        case .never: "No soreness at all after that session."
        case .healedEarly: "Sore, but it was gone well before today."
        case .healedOnTime: "Sore until about today. Recovered just enough."
        case .stillSore: "Still sore now. You haven't recovered yet."
        }
    }
}

public enum Pump: Int, CaseIterable, Codable {
    case low, moderate, great
    public var label: String { ["Low", "Moderate", "Great"][rawValue] }
    public var meaning: String {
        [
            "The muscle barely felt full or tight.",
            "Some fullness, but it faded quickly.",
            "Very full and tight, hard to miss.",
        ][rawValue]
    }
}

public enum Workload: Int, CaseIterable, Codable {
    case easy, good, hard, tooMuch
    public var label: String { ["Easy", "Pretty good", "Pushed my limits", "Too much"][rawValue] }
    public var meaning: String {
        [
            "You could have done a lot more sets.",
            "Challenging, with a few sets left in the tank.",
            "About all you could do. Another set would be a struggle.",
            "More than you could recover from. Form or reps fell apart.",
        ][rawValue]
    }
}

public enum JointPain: Int, CaseIterable, Codable {
    case none, low, moderate, severe
    public var label: String { ["None", "Low", "Moderate", "A lot"][rawValue] }
    public var meaning: String {
        [
            "Joints felt fine.",
            "Some awareness in a joint, but nothing that hurt.",
            "The joints are taking a beating from this exercise.",
            "Sharp or lasting pain. Stop or swap the exercise.",
        ][rawValue]
    }
}

/// Soreness is reported at the start of the next session that trains the muscle, then written back here.
public struct MuscleFeedback: Equatable, Codable {
    public var soreness: Soreness?
    public var pump: Pump?
    public var workload: Workload?
    public var jointPain: JointPain?

    public init(soreness: Soreness? = nil, pump: Pump? = nil, workload: Workload? = nil, jointPain: JointPain? = nil) {
        self.soreness = soreness
        self.pump = pump
        self.workload = workload
        self.jointPain = jointPain
    }
}

public struct TemplateSlot: Hashable {
    public let muscle: Muscle
    public let exercise: String
}

public struct TemplateDay: Hashable {
    public let name: String
    let exerciseNames: [String]
    public let slots: [TemplateSlot]
}

public enum TemplateEmphasis: String, CaseIterable, Identifiable {
    case wholeBody, upperBody, lowerBody, glutesAndAbs, chestAndTriceps, backAndBiceps, chestAndBack, armsAndShoulders
    case timeSaver
    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .wholeBody: "Whole Body"
        case .upperBody: "Upper Body"
        case .lowerBody: "Lower Body"
        case .glutesAndAbs: "Glutes & Abs"
        case .chestAndTriceps: "Chest & Triceps"
        case .backAndBiceps: "Back & Biceps"
        case .chestAndBack: "Chest & Back"
        case .armsAndShoulders: "Arms & Shoulders"
        case .timeSaver: "Time-Saver"
        }
    }
}

public struct ProgramTemplate: Identifiable, Hashable {
    public let name: String
    /// Nil for a custom template.
    public let emphasis: TemplateEmphasis?
    public let summary: String
    public let days: [TemplateDay]
    public var id: String { name }

    /// How many exercises the template gives each muscle across a week, most first, ties in catalog order.
    public var weeklyExercises: [(muscle: Muscle, count: Int)] {
        let counts = Dictionary(days.flatMap(\.slots).map { ($0.muscle, 1) }, uniquingKeysWith: +)
        return Muscle.allCases.compactMap { muscle in counts[muscle].map { (muscle, $0) } }
            .enumerated().sorted { ($0.element.count, -$0.offset) > ($1.element.count, -$1.offset) }
            .map(\.element)
    }
}
