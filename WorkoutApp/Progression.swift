import Foundation

// SKETCH: every body below is the contract the implementer fills in. Foundation only.

struct LoggedSet: Equatable {
    var weight: Double
    var reps: Int
}

/// A target for one set. A nil weight means "calibrate": the lifter picks a load that lands at the target RIR.
struct SetTarget: Equatable {
    var weight: Double?
    var reps: Int?
}

/// Where a mesocycle week sits: accumulation weeks count down RIR, the final week is a deload.
enum WeekPhase: Equatable {
    case accumulation(rir: Int)
    case deload
}

enum Progression {
    /// Week 0-based. Weeks 0..<accumulationWeeks are accumulation, week == accumulationWeeks is deload.
    /// RIR = min(3, accumulationWeeks - 1 - week), so a 4-week block runs 3, 2, 1, 0.
    static func phase(week: Int, accumulationWeeks: Int) -> WeekPhase {
        fatalError("not implemented")
    }

    /// Sets to add to (or remove from) one muscle in one session next week, from that session's feedback.
    /// Table-driven on soreness x workload, nudged by pump; joint pain at moderate or worse caps it at 0.
    /// Missing feedback returns 0.
    static func setDelta(_ feedback: MuscleFeedback) -> Int {
        fatalError("not implemented")
    }

    /// Spreads a muscle's set delta across its exercises in one session.
    /// Adds go to the exercise with the fewest sets, removals come from the most. No exercise drops below 1.
    /// `weeklyRoom` is how many sets the muscle can still gain before its weekly MRV.
    static func distribute(delta: Int, across counts: [Int], weeklyRoom: Int) -> [Int] {
        fatalError("not implemented")
    }

    /// Week-1 sets for each exercise of a muscle in one session: MEV split over its weekly sessions
    /// and its exercises in this session, at least 2 sets per exercise.
    static func initialSetsPerExercise(muscle: Muscle, sessionsPerWeek: Int, exercisesInSession: Int) -> Int {
        fatalError("not implemented")
    }

    /// Next week's targets for one exercise from what was logged last week.
    /// Holds load and adds the reps freed by the lower RIR; once reps pass the top of `repRange`,
    /// adds `increment` and re-derives reps from estimated 1RM. A set that fell 2+ reps short of its
    /// target repeats its target. Missing logs repeat the previous target.
    static func nextTargets(previousTargets: [SetTarget],
                            logged: [LoggedSet?],
                            previousRIR: Int,
                            targetRIR: Int,
                            repRange: ClosedRange<Int>,
                            increment: Double,
                            setCount: Int) -> [SetTarget] {
        fatalError("not implemented")
    }

    /// Deload: half the sets (rounded up) of the last accumulation week, week-1 loads and reps.
    static func deloadTargets(firstWeek: [SetTarget], lastAccumulationSetCount: Int) -> [SetTarget] {
        fatalError("not implemented")
    }

    /// Epley estimate counting reps in reserve as reps the lifter could have done.
    static func estimatedOneRepMax(weight: Double, reps: Int, rir: Int = 0) -> Double {
        fatalError("not implemented")
    }
}
