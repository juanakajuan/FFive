import Foundation

/// How a logged weight becomes the load the lifter moves, and how far progression steps it.
/// A bodyweight lift logs load added to body weight, negative for assistance, so its moved load is
/// the logged weight plus body weight. Without a body weight that load is unknown: progression holds
/// the weight and adds reps, and the set says nothing about strength.
struct Loading: Equatable {
    let equipment: Equipment
    let bodyweight: Double?

    init(equipment: Equipment?, bodyweight: Double?) {
        self.equipment = equipment ?? .machine
        self.bodyweight = bodyweight
    }

    var addsToBodyweight: Bool { equipment == .bodyweight }

    /// What a logged weight is added to, nil when body weight is needed and missing.
    var offset: Double? { addsToBodyweight ? bodyweight : 0 }

    func movedLoad(of weight: Double) -> Double? { offset.map { weight + $0 } }

    /// Smallest sensible jump in the logged weight, 0 when the moved load is unknown.
    func increment(_ unit: WeightUnit) -> Double {
        offset == nil ? 0 : equipment.increment(unit)
    }
}

extension Exercise {
    var loading: Loading { Loading(equipment: info?.equipment, bodyweight: workout?.bodyweight) }

    /// A logged weight as the lifter reads it: "BW", "BW+25" or "BW−40" for a bodyweight lift, else the weight
    /// followed by `unit` when one is given.
    public func weightText(_ weight: Double, unit: WeightUnit? = nil) -> String {
        guard loading.addsToBodyweight else { return plainWeightText(weight, unit: unit) }
        if weight == 0 { return "BW" }
        return "BW\(weight > 0 ? "+" : "\u{2212}")\(formatWeight(abs(weight)))"
    }
}

extension SetEntry {
    public func weightText(unit: WeightUnit? = nil) -> String {
        exercise?.weightText(weight, unit: unit) ?? plainWeightText(weight, unit: unit)
    }
}

private func plainWeightText(_ weight: Double, unit: WeightUnit?) -> String {
    unit.map { "\(formatWeight(weight)) \($0.rawValue)" } ?? formatWeight(weight)
}

extension ExerciseCatalog {
    static func loading(for id: ExerciseID, bodyweight: Double?) -> Loading {
        Loading(equipment: info(id)?.equipment, bodyweight: bodyweight)
    }
}
