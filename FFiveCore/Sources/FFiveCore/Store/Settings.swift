import Foundation
import Observation

@MainActor
@Observable
public final class Settings {
    private static let weightUnitKey = "weightUnit"
    private static let autoMatchWeightsKey = "autoMatchWeights"
    private static let hiddenExercisesKey = "hiddenExercises"

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

    @ObservationIgnored private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        weightUnit = defaults.string(forKey: Self.weightUnitKey).flatMap(WeightUnit.init(rawValue:)) ?? .lb
        hiddenExercises = Set(
            (defaults.stringArray(forKey: Self.hiddenExercisesKey) ?? []).map(ExerciseID.init(rawValue:)))
        autoMatchWeights = defaults.object(forKey: Self.autoMatchWeightsKey) as? Bool ?? true
    }
}
