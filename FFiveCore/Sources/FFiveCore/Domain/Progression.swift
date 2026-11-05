import Foundation

public struct LoggedSet: Equatable {
    public var weight: Double
    public var reps: Int
}

/// A target for one set. A nil weight means "calibrate": the lifter picks a load that lands at the target RIR.
public struct SetTarget: Equatable {
    public var weight: Double?
    public var reps: Int?

    static let calibrate = SetTarget(weight: nil, reps: nil)
}

/// Where a mesocycle week sits: accumulation weeks count down RIR, the final week is a deload.
public enum WeekPhase: Equatable {
    case accumulation(rir: Int)
    case deload

    public var rir: Int? {
        if case .accumulation(let rir) = self { return rir }
        return nil
    }
}

public enum Progression {
    /// Week 0-based. Weeks 0..<accumulationWeeks are accumulation, week == accumulationWeeks is deload.
    /// RIR = min(3, accumulationWeeks - 1 - week), so a 4-week block runs 3, 2, 1, 0.
    public static func phase(week: Int, accumulationWeeks: Int) -> WeekPhase {
        guard week < accumulationWeeks else { return .deload }
        return .accumulation(rir: max(0, min(3, accumulationWeeks - 1 - week)))
    }

    /// Rows are `Soreness`, columns are `Workload`, both indexed by raw value.
    private static let setDeltaTable: [[Int]] = [
        //  easy good hard tooMuch
        [3, 2, 1, 0],  // never
        [2, 1, 1, 0],  // healedEarly
        [1, 0, 0, -1],  // healedOnTime
        [0, 0, -1, -1],  // stillSore
    ]

    /// Sets to add to (or remove from) one muscle in one session next week, from that session's feedback.
    /// Table-driven on soreness x workload, nudged by pump; joint pain at moderate or worse caps it at 0.
    /// Missing feedback returns 0.
    public static func setDelta(_ feedback: MuscleFeedback) -> Int {
        guard let soreness = feedback.soreness, let workload = feedback.workload else { return 0 }
        var delta = setDeltaTable[soreness.rawValue][workload.rawValue]
        switch feedback.pump {
        case .low where delta > 0: delta += 1
        case .great where delta >= 2: delta -= 1
        default: break
        }
        delta = min(3, max(-1, delta))
        if let pain = feedback.jointPain, pain.rawValue >= JointPain.moderate.rawValue {
            delta = min(delta, 0)
        }
        return delta
    }

    /// Spreads a muscle's set delta across its exercises in one session.
    /// Adds go to the exercise with the fewest sets, removals come from the most. No exercise drops below 1.
    /// `weeklyRoom` is how many sets the muscle can still gain before its weekly MRV.
    static func distribute(delta: Int, across counts: [Int], weeklyRoom: Int) -> [Int] {
        var result = counts
        guard !result.isEmpty else { return result }
        if delta > 0 {
            for _ in 0..<min(delta, max(0, weeklyRoom)) {
                let index = result.indices.min { result[$0] < result[$1] }!
                result[index] += 1
            }
        } else {
            for _ in 0..<(-delta) {
                guard let index = result.indices.filter({ result[$0] > 1 }).max(by: { result[$0] < result[$1] }) else {
                    break
                }
                result[index] -= 1
            }
        }
        return result
    }

    /// Week-1 sets for each exercise of a muscle in one session: MEV split over its weekly sessions
    /// and its exercises in this session, at least 2 sets per exercise.
    static func initialSetsPerExercise(muscle: Muscle, sessionsPerWeek: Int, exercisesInSession: Int) -> Int {
        let slots = max(1, sessionsPerWeek) * max(1, exercisesInSession)
        let share = (muscle.landmarks.mev + slots - 1) / slots
        return max(2, share)
    }

    /// Next week's targets for one exercise from what was logged last week.
    /// Holds load and adds the reps freed by the lower RIR; once reps pass the top of `repRange`,
    /// adds `increment` and re-derives reps from estimated 1RM. A set that fell 2+ reps short of its
    /// target repeats its target. Missing logs repeat the previous target.
    /// Myo-rep and myo-rep match sets are excluded from load and rep targets: they are taken near failure after
    /// short rest, so their reps say nothing about the straight-set target. Their slot repeats its previous target
    /// (`SetEntry.logged` is nil for them), and they still count as sets toward weekly volume.
    static func nextTargets(
        previousTargets: [SetTarget],
        logged: [LoggedSet?],
        previousRIR: Int,
        targetRIR: Int,
        repRange: ClosedRange<Int>,
        increment: Double,
        setCount: Int
    ) -> [SetTarget] {
        let progressed = previousTargets.indices.map { index -> SetTarget in
            let target = previousTargets[index]
            guard index < logged.count, let log = logged[index] else { return target }
            if let targetReps = target.reps, log.reps <= targetReps - 2 { return target }

            let reps = log.reps + (previousRIR - targetRIR)
            guard increment > 0, reps > repRange.upperBound else {
                return SetTarget(weight: log.weight, reps: reps)
            }
            let oneRepMax = estimatedOneRepMax(weight: log.weight, reps: log.reps, rir: previousRIR)
            let load = roundDown(log.weight + increment, to: increment)
            let solved = self.reps(atLoad: load, rir: targetRIR, oneRepMax: oneRepMax)
            return SetTarget(weight: load, reps: min(repRange.upperBound, max(repRange.lowerBound, solved)))
        }
        return resized(progressed, to: setCount)
    }

    /// Deload: half the sets (rounded up) of the last accumulation week, week-1 loads and reps.
    static func deloadTargets(firstWeek: [SetTarget], lastAccumulationSetCount: Int) -> [SetTarget] {
        resized(firstWeek, to: max(1, (lastAccumulationSetCount + 1) / 2))
    }

    /// Epley estimate counting reps in reserve as reps the lifter could have done.
    static func estimatedOneRepMax(weight: Double, reps: Int, rir: Int = 0) -> Double {
        weight * (1 + Double(reps + rir) / 30)
    }

    /// A first-week rep target between the bottom and the middle of the range.
    public static func startingReps(in repRange: ClosedRange<Int>) -> Int {
        let middle = (repRange.lowerBound + repRange.upperBound) / 2
        return (repRange.lowerBound + middle) / 2
    }

    /// The load that leaves `rir` reps in reserve after `reps` reps, from an estimated 1RM.
    static func load(forReps reps: Int, rir: Int, oneRepMax: Double, increment: Double) -> Double {
        roundDown(oneRepMax / (1 + Double(reps + rir) / 30), to: increment)
    }

    /// Reps that leave `rir` in reserve at `load`, from an estimated 1RM. Inverse of `estimatedOneRepMax`.
    public static func reps(atLoad load: Double, rir: Int, oneRepMax: Double) -> Int {
        guard load > 0 else { return 0 }
        return Int((30 * (oneRepMax / load - 1)).rounded(.down)) - rir
    }

    /// Loads round down so a prescription never asks for more than the math supports.
    public static func roundDown(_ weight: Double, to increment: Double) -> Double {
        guard increment > 0 else { return weight }
        return (weight / increment + 1e-9).rounded(.down) * increment
    }

    /// Trims from the end, or repeats the last target, to reach `count`.
    private static func resized(_ targets: [SetTarget], to count: Int) -> [SetTarget] {
        guard count > 0 else { return [] }
        guard let last = targets.last else { return Array(repeating: .calibrate, count: count) }
        return Array(targets.prefix(count)) + Array(repeating: last, count: max(0, count - targets.count))
    }
}
