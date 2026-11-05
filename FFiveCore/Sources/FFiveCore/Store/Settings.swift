import Foundation
import Observation

@MainActor
@Observable
public final class Settings {
    private static let weightUnitKey = "weightUnit"

    /// The unit new prescriptions use. Loads already logged keep their numbers.
    public var weightUnit: WeightUnit {
        didSet { defaults.set(weightUnit.rawValue, forKey: Self.weightUnitKey) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        weightUnit = defaults.string(forKey: Self.weightUnitKey).flatMap(WeightUnit.init(rawValue:)) ?? .lb
    }
}
