import Foundation

extension WeightUnit {
    /// The plate sizes a gym stocks, heaviest first.
    public var plates: [Double] {
        switch self {
        case .lb: [45, 35, 25, 10, 5, 2.5]
        case .kg: [25, 20, 15, 10, 5, 2.5, 1.25]
        }
    }

    public var defaultBarWeight: Double {
        switch self {
        case .lb: 45
        case .kg: 20
        }
    }
}

/// The plates to load on each side of a bar for a target weight.
public struct PlateLoad: Equatable {
    public let target: Double
    public let bar: Double
    /// One side's plates, heaviest first. A size repeats once per plate.
    public let perSide: [Double]

    public var total: Double { Self.hundredths(bar, perSide) }
    /// Positive when the load is over the target, negative when under.
    public var offBy: Double { Double(Self.cents(total) - Self.cents(target)) / 100 }
    public var isExact: Bool { Self.cents(total) == Self.cents(target) }

    /// The loadable weight nearest the target, with unlimited plates of each size.
    /// A tie between two loads takes the lighter one, so the bar is never overloaded.
    /// A target at or under the bar, or no plates, loads the bar alone.
    public static func closest(to target: Double, bar: Double, plates: [Double]) -> PlateLoad {
        let sizes = Set(plates.map(cents).filter { $0 > 0 }).sorted(by: >)
        let twoSides = cents(target) - cents(bar)
        guard let smallest = sizes.last, twoSides > 0 else {
            return PlateLoad(target: target, bar: bar, perSide: [])
        }
        var remaining = (twoSides + smallest - 1) / (2 * smallest) * smallest
        var perSide: [Double] = []
        for size in sizes {
            while remaining >= size {
                perSide.append(Double(size) / 100)
                remaining -= size
            }
        }
        return PlateLoad(target: target, bar: bar, perSide: perSide)
    }

    private static func cents(_ weight: Double) -> Int { Int((weight * 100).rounded()) }

    private static func hundredths(_ bar: Double, _ perSide: [Double]) -> Double {
        Double(cents(bar) + 2 * perSide.map(cents).reduce(0, +)) / 100
    }
}
