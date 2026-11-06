import Foundation
import Observation

@MainActor
@Observable
public final class Settings {
    private static let weightUnitKey = "weightUnit"
    private static let autoMatchWeightsKey = "autoMatchWeights"
    private static let hiddenExercisesKey = "hiddenExercises"
    private static let equipmentKey = "equipment"

    /// The unit new prescriptions use. Loads already logged keep their numbers.
    public var weightUnit: WeightUnit {
        didSet { defaults.set(weightUnit.rawValue, forKey: Self.weightUnitKey) }
    }

    /// An edited weight also changes later unlogged sets of that exercise that had the same weight.
    public var autoMatchWeights: Bool {
        didSet { defaults.set(autoMatchWeights, forKey: Self.autoMatchWeightsKey) }
    }

    /// Catalog exercises the lifter hid from pickers. A custom exercise keeps its own `isHidden`.
    public var hiddenExercises: Set<ExerciseID> {
        didSet { defaults.set(hiddenExercises.map(\.rawValue).sorted(), forKey: Self.hiddenExercisesKey) }
    }

    /// The equipment the lifter has. Never empty.
    public private(set) var equipment: Set<Equipment> {
        didSet { defaults.set(equipment.map(\.rawValue).sorted(), forKey: Self.equipmentKey) }
    }

    public var filtersEquipment: Bool { equipment != Set(Equipment.allCases) }

    /// Refuses to remove the last item so the exercise lists never go empty.
    public func toggle(_ item: Equipment) {
        if equipment.contains(item) {
            if equipment.count > 1 { equipment.remove(item) }
        } else {
            equipment.insert(item)
        }
    }

    @ObservationIgnored private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        weightUnit = defaults.string(forKey: Self.weightUnitKey).flatMap(WeightUnit.init(rawValue:)) ?? .lb
        hiddenExercises = Set(
            (defaults.stringArray(forKey: Self.hiddenExercisesKey) ?? []).map(ExerciseID.init(rawValue:)))
        autoMatchWeights = defaults.object(forKey: Self.autoMatchWeightsKey) as? Bool ?? true
        let stored = Set((defaults.stringArray(forKey: Self.equipmentKey) ?? []).compactMap(Equipment.init(rawValue:)))
        equipment = stored.isEmpty ? Set(Equipment.allCases) : stored
    }
}
