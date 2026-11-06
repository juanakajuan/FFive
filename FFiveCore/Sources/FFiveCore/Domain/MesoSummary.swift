import Foundation

/// How a block went, read from its finished sessions. Every per-week array has one entry per week of the block,
/// deload last.
public struct MesoSummary {
    public struct MuscleSets: Identifiable {
        public let muscle: Muscle
        public let perWeek: [Int]
        public var id: Muscle { muscle }
    }

    /// First and last estimated 1RM of an exercise across the block's hard weeks.
    public struct StrengthChange: Identifiable {
        public let id: ExerciseID
        public let name: String
        public let first: Double
        public let last: Double
        public var change: Double { last - first }
        public var percent: Double { first > 0 ? change / first : 0 }
    }

    public struct FeedbackTrend: Identifiable {
        public struct Row: Identifiable {
            public let metric: FeedbackMetric
            /// The week's mean answer, from 0 for the lowest to 1 for the highest, or nil when none was given.
            public let perWeek: [Double?]
            public var id: FeedbackMetric { metric }
        }

        public let muscle: Muscle
        public let rows: [Row]
        public var id: Muscle { muscle }
    }

    public let weeks: Int
    public let deloadWeek: Int
    public let sets: [MuscleSets]
    public let strength: [StrengthChange]
    public let feedback: [FeedbackTrend]
}

public enum FeedbackMetric: CaseIterable, Identifiable {
    case soreness, pump, workload, jointPain

    public var id: Self { self }

    public var label: String {
        switch self {
        case .soreness: "Soreness"
        case .pump: "Pump"
        case .workload: "Workload"
        case .jointPain: "Joint pain"
        }
    }

    func normalized(_ feedback: MuscleFeedback) -> Double? {
        switch self {
        case .soreness: feedback.soreness.map { Double($0.rawValue) / Double(Soreness.allCases.count - 1) }
        case .pump: feedback.pump.map { Double($0.rawValue) / Double(Pump.allCases.count - 1) }
        case .workload: feedback.workload.map { Double($0.rawValue) / Double(Workload.allCases.count - 1) }
        case .jointPain: feedback.jointPain.map { Double($0.rawValue) / Double(JointPain.allCases.count - 1) }
        }
    }
}

extension Mesocycle {
    public var summary: MesoSummary {
        let weeks = totalWeeks
        let finished = workouts.filter(\.isFinished).sorted { $0.startDate < $1.startDate }
        let inBlock = finished.compactMap { workout in workout.week.map { (week: $0, workout: workout) } }
            .filter { $0.week < weeks }

        var sets: [Muscle: [Int]] = [:]
        var feedback: [Muscle: [FeedbackMetric: [[Double]]]] = [:]
        var strength: [ExerciseID: (name: String, first: Double, last: Double)] = [:]

        for (week, workout) in inBlock {
            for exercise in workout.exercises {
                guard let muscle = exercise.muscle else { continue }
                let done = exercise.sets.filter(\.isDone).count
                sets[muscle, default: Array(repeating: 0, count: weeks)][week] += done
            }
            for record in workout.feedback {
                guard let muscle = record.muscle else { continue }
                for metric in FeedbackMetric.allCases {
                    guard let value = metric.normalized(record.value) else { continue }
                    feedback[muscle, default: [:]][metric, default: Array(repeating: [], count: weeks)][week]
                        .append(value)
                }
            }
            for exercise in workout.sortedExercises {
                guard let oneRepMax = exercise.strongestSet?.oneRepMax else { continue }
                let name = exercise.info?.name ?? exercise.name
                if let seen = strength[exercise.key] {
                    strength[exercise.key] = (name, seen.first, oneRepMax)
                } else {
                    strength[exercise.key] = (name, oneRepMax, oneRepMax)
                }
            }
        }

        let muscleOrder = Muscle.allCases
        return MesoSummary(
            weeks: weeks,
            deloadWeek: accumulationWeeks,
            sets: muscleOrder.compactMap { muscle in
                sets[muscle].flatMap { $0.contains { $0 > 0 } ? .init(muscle: muscle, perWeek: $0) : nil }
            },
            strength: strength.map {
                .init(id: $0.key, name: $0.value.name, first: $0.value.first, last: $0.value.last)
            }
            .sorted { ($0.percent, $1.name) > ($1.percent, $0.name) },
            feedback: muscleOrder.compactMap { muscle in
                guard let byMetric = feedback[muscle] else { return nil }
                let rows = FeedbackMetric.allCases.compactMap { metric -> MesoSummary.FeedbackTrend.Row? in
                    guard let perWeek = byMetric[metric] else { return nil }
                    return .init(
                        metric: metric,
                        perWeek: perWeek.map { $0.isEmpty ? nil : $0.reduce(0, +) / Double($0.count) })
                }
                return .init(muscle: muscle, rows: rows)
            })
    }
}
