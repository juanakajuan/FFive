import Foundation

extension MusclePriority {
    /// What the guided builder starts each muscle at: small muscles that the big lifts already train are maintained.
    public static func guidedDefault(for muscle: Muscle) -> MusclePriority {
        switch muscle {
        case .frontDelts, .traps, .forearms, .abs: .maintain
        default: .normal
        }
    }

    /// Sessions a week that train a muscle at this priority, when the week has `daysPerWeek` training days.
    /// Emphasized muscles train up to three times, grown ones twice and maintained ones once.
    public func weeklyFrequency(daysPerWeek: Int) -> Int {
        let wanted =
            switch self {
            case .emphasize: 3
            case .normal: 2
            case .maintain: 1
            }
        return min(max(1, daysPerWeek), wanted)
    }

    fileprivate var rank: Int {
        switch self {
        case .emphasize: 0
        case .normal: 1
        case .maintain: 2
        }
    }
}

extension MesoDraft {
    public static let guidedDaysPerWeek = 2...6

    /// A draft of `daysPerWeek` days that trains every muscle as often as its priority asks, with each muscle's
    /// sessions spread out over the week and each day holding about the same number of muscles. Every slot is a
    /// muscle with no exercise yet. A muscle missing from `priorities` is trained at its guided default.
    public init(daysPerWeek: Int, priorities: [Muscle: MusclePriority]) {
        let dayCount = Self.guidedDaysPerWeek.clamped(daysPerWeek)
        let priority = { (muscle: Muscle) in priorities[muscle] ?? .guidedDefault(for: muscle) }
        let order = Muscle.allCases.enumerated()
            .sorted { (priority($0.element).rank, $0.offset) < (priority($1.element).rank, $1.offset) }
            .map(\.element)
        let total = order.reduce(0) { $0 + priority($1).weeklyFrequency(daysPerWeek: dayCount) }
        let cap = (total + dayCount - 1) / dayCount
        var plan = [[Muscle]](repeating: [], count: dayCount)
        for muscle in order {
            let sessions = priority(muscle).weeklyFrequency(daysPerWeek: dayCount)
            for day in Self.spreadDays(for: muscle, sessions: sessions, over: plan, cap: cap) {
                plan[day].append(muscle)
            }
        }
        self.init(template: nil)
        name = "\(dayCount)-Day Plan"
        let names = Self.dayNames(plan.map { $0.filter { priority($0) != .maintain } })
        days = plan.enumerated().map { index, muscles in
            Day(name: names[index], slots: muscles.map { Slot(muscle: $0) })
        }
        self.priorities = Dictionary(uniqueKeysWithValues: Muscle.allCases.map { ($0, priority($0)) })
    }

    /// The days, evenly spaced through the week, that best fit `sessions` more slots of `muscle` into `plan`. Days
    /// that stay within `cap` slots come first, then days that already train the same half of the body, then the
    /// lightest days.
    private static func spreadDays(for muscle: Muscle, sessions: Int, over plan: [[Muscle]], cap: Int) -> [Int] {
        let count = plan.count
        let candidates = (0..<count).map { offset in
            (0..<sessions).map { (offset + $0 * count / sessions) % count }
        }
        func score(_ days: [Int]) -> (Int, Int, Int, Int) {
            let busiest = days.map { plan[$0].count }.max() ?? 0
            let affinity = days.reduce(0) { total, day in
                total + plan[day].reduce(0) { $0 + muscle.affinity(with: $1) }
            }
            return (busiest < cap ? 0 : 1, -affinity, busiest, days.reduce(0) { $0 + plan[$1].count })
        }
        return candidates.min { score($0) < score($1) } ?? []
    }

    /// "Upper", "Lower" or "Full Body" for each day by the halves its `muscles` train, lettered when a name repeats.
    private static func dayNames(_ muscles: [[Muscle]]) -> [String] {
        let base = muscles.map { day -> String in
            let halves = Set(day.compactMap(\.half))
            return halves.count == 1 ? (halves.first == .lower ? "Lower" : "Upper") : "Full Body"
        }
        var seen: [String: Int] = [:]
        return base.map { name in
            guard base.filter({ $0 == name }).count > 1 else { return name }
            let letter = seen[name, default: 0]
            seen[name] = letter + 1
            return "\(name) \(Character(UnicodeScalar(UInt8(65 + letter))))"
        }
    }
}

private enum BodyHalf { case upper, lower }

extension Muscle {
    /// Nil for abs, which fit with either half.
    fileprivate var half: BodyHalf? {
        switch self {
        case .quads, .hamstrings, .glutes, .calves: .lower
        case .abs: nil
        default: .upper
        }
    }

    /// 1 for a muscle from the same half of the body, -1 for one from the other half, 0 when either is abs.
    fileprivate func affinity(with other: Muscle) -> Int {
        guard let half, let otherHalf = other.half else { return 0 }
        return half == otherHalf ? 1 : -1
    }
}

extension ClosedRange where Bound == Int {
    fileprivate func clamped(_ value: Int) -> Int { Swift.min(upperBound, Swift.max(lowerBound, value)) }
}
