import XCTest

@testable import FFiveCore

final class EngineTests: XCTestCase {
    func expect<T: Equatable>(
        _ name: String, _ actual: T, _ expected: T, file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertEqual(actual, expected, name, file: file, line: line)
    }

    func expectClose(
        _ name: String, _ actual: Double, _ expected: Double, file: StaticString = #filePath, line: UInt = #line
    ) {
        expect(name, (actual * 100).rounded() / 100, expected, file: file, line: line)
    }

    func t(_ weight: Double?, _ reps: Int?) -> SetTarget { SetTarget(weight: weight, reps: reps) }
    func log(_ weight: Double, _ reps: Int) -> LoggedSet { LoggedSet(weight: weight, reps: reps) }

    func feedback(
        _ soreness: Soreness?, _ workload: Workload?, pump: Pump? = .moderate, pain: JointPain? = JointPain.none
    ) -> MuscleFeedback {
        MuscleFeedback(soreness: soreness, pump: pump, workload: workload, jointPain: pain)
    }

    func schedule(_ weeks: Int) -> [WeekPhase] {
        (0...weeks).map { Progression.phase(week: $0, accumulationWeeks: weeks) }
    }

    func testWeekLabels() {
        let phases = schedule(3)
        expect(
            "short labels, 3 weeks", phases.enumerated().map { $1.shortLabel(week: $0) },
            ["W1", "W2", "W3", "DL"])
        expect(
            "long labels, 3 weeks", phases.enumerated().map { $1.longLabel(week: $0) },
            ["Week 1", "Week 2", "Week 3", "Deload"])
        expect("badges, 3 weeks", phases.map(\.badgeText), ["2 RIR", "1 RIR", "0 RIR", "Deload"])
    }

    func testRirSchedule() {
        expect(
            "rir schedule, 3 weeks: 2 1 0 then deload", schedule(3),
            [.accumulation(rir: 2), .accumulation(rir: 1), .accumulation(rir: 0), .deload])
        expect(
            "rir schedule, 4 weeks: 3 2 1 0 then deload", schedule(4),
            [.accumulation(rir: 3), .accumulation(rir: 2), .accumulation(rir: 1), .accumulation(rir: 0), .deload])
        expect(
            "rir schedule, 6 weeks: 3 3 3 2 1 0 then deload", schedule(6),
            [
                .accumulation(rir: 3), .accumulation(rir: 3), .accumulation(rir: 3),
                .accumulation(rir: 2), .accumulation(rir: 1), .accumulation(rir: 0), .deload,
            ])
    }

    func testSetDeltaTable() {
        let expected: [Soreness: [Int]] = [
            .never: [3, 2, 1, 0],
            .healedEarly: [2, 1, 1, 0],
            .healedOnTime: [1, 0, 0, -1],
            .stillSore: [0, 0, -1, -1],
        ]
        for soreness in Soreness.allCases {
            let row = Workload.allCases.map { Progression.setDelta(feedback(soreness, $0)) }
            expect("setDelta row \(soreness) across easy/good/hard/tooMuch", row, expected[soreness]!)
        }
    }

    func testSetDeltaModifiers() {
        expect(
            "low pump adds 1 to a positive delta", Progression.setDelta(feedback(.healedOnTime, .easy, pump: .low)), 2)
        expect(
            "low pump leaves a zero delta alone", Progression.setDelta(feedback(.healedOnTime, .good, pump: .low)), 0)
        expect(
            "low pump leaves a negative delta alone", Progression.setDelta(feedback(.stillSore, .tooMuch, pump: .low)),
            -1)
        expect("low pump on the top cell clamps at 3", Progression.setDelta(feedback(.never, .easy, pump: .low)), 3)
        expect("great pump trims a delta of 2", Progression.setDelta(feedback(.never, .good, pump: .great)), 1)
        expect("great pump trims a delta of 3", Progression.setDelta(feedback(.never, .easy, pump: .great)), 2)
        expect(
            "great pump leaves a delta of 1 alone", Progression.setDelta(feedback(.healedEarly, .good, pump: .great)), 1
        )
        expect("missing pump uses the table value", Progression.setDelta(feedback(.never, .good, pump: nil)), 2)
        expect("low joint pain does not cap", Progression.setDelta(feedback(.never, .easy, pain: .low)), 3)
        expect("moderate joint pain caps at 0", Progression.setDelta(feedback(.never, .easy, pain: .moderate)), 0)
        expect(
            "severe joint pain caps at 0",
            Progression.setDelta(feedback(.healedEarly, .good, pump: .low, pain: .severe)), 0)
        expect("joint pain keeps a removal", Progression.setDelta(feedback(.stillSore, .hard, pain: .severe)), -1)
        expect("missing soreness returns 0", Progression.setDelta(feedback(nil, .easy)), 0)
        expect("missing workload returns 0", Progression.setDelta(feedback(.never, nil)), 0)
    }

    func testSetDeltaPriority() {
        func delta(_ soreness: Soreness, _ workload: Workload, _ priority: MusclePriority, pain: JointPain = .none)
            -> Int
        {
            Progression.setDelta(feedback(soreness, workload, pain: pain), priority: priority)
        }
        expect("emphasize adds 1 to a positive delta", delta(.healedEarly, .good, .emphasize), 2)
        expect("emphasize leaves a zero delta alone", delta(.healedOnTime, .good, .emphasize), 0)
        expect("emphasize leaves a removal alone", delta(.stillSore, .tooMuch, .emphasize), -1)
        expect("emphasize clamps at 3", delta(.never, .easy, .emphasize), 3)
        expect("emphasize keeps the joint pain cap", delta(.never, .easy, .emphasize, pain: .moderate), 0)
        expect("maintain never adds a set", delta(.never, .easy, .maintain), 0)
        expect("maintain keeps a removal", delta(.stillSore, .tooMuch, .maintain), -1)
        expect("normal matches the table", delta(.healedEarly, .good, .normal), 1)
    }

    func testInitialSetsPriority() {
        func sets(_ muscle: Muscle, _ priority: MusclePriority, sessions: Int, exercises: Int) -> Int {
            Progression.initialSetsPerExercise(
                muscle: muscle, priority: priority, sessionsPerWeek: sessions, exercisesInSession: exercises)
        }
        expect("normal chest splits MEV 10 over 2 slots", sets(.chest, .normal, sessions: 2, exercises: 1), 5)
        expect("emphasized chest also starts at MEV", sets(.chest, .emphasize, sessions: 2, exercises: 1), 5)
        expect("maintained chest splits MV 8 over 2 slots", sets(.chest, .maintain, sessions: 2, exercises: 1), 4)
        expect(
            "maintained hamstrings split MV 3 over 4 slots", sets(.hamstrings, .maintain, sessions: 2, exercises: 2), 1)
        expect(
            "maintained side delts with MV 0 still get 1 set", sets(.sideDelts, .maintain, sessions: 1, exercises: 1), 1
        )
        expect("normal keeps the 2-set floor", sets(.glutes, .normal, sessions: 1, exercises: 1), 2)
    }

    func testDistribute() {
        expect(
            "distribute adds to the smallest", Progression.distribute(delta: 1, across: [3, 2], weeklyRoom: 10), [3, 3])
        expect(
            "distribute spreads adds smallest-first",
            Progression.distribute(delta: 2, across: [2, 2, 3], weeklyRoom: 10), [3, 3, 3])
        expect(
            "distribute removes from the largest", Progression.distribute(delta: -1, across: [2, 4], weeklyRoom: 10),
            [2, 3])
        expect(
            "distribute never drops an exercise below 1",
            Progression.distribute(delta: -1, across: [1, 1], weeklyRoom: 10), [1, 1])
        expect(
            "distribute stops removing at the floor",
            Progression.distribute(delta: -3, across: [2, 1], weeklyRoom: 10), [1, 1])
        expect(
            "distribute caps adds at weekly room", Progression.distribute(delta: 3, across: [2, 2], weeklyRoom: 1),
            [3, 2])
        expect(
            "distribute adds nothing with no room", Progression.distribute(delta: 2, across: [2, 2], weeklyRoom: 0),
            [2, 2])
        expect(
            "distribute treats negative room as none",
            Progression.distribute(delta: 2, across: [2, 2], weeklyRoom: -3), [2, 2])
        expect(
            "distribute zero delta is identity", Progression.distribute(delta: 0, across: [4, 2], weeklyRoom: 10),
            [4, 2])
        expect("distribute empty session", Progression.distribute(delta: 2, across: [], weeklyRoom: 10), [])
    }

    func testInitialSets() {
        expect(
            "initial sets: chest MEV 10 over 2 sessions x 2 exercises",
            Progression.initialSetsPerExercise(muscle: .chest, sessionsPerWeek: 2, exercisesInSession: 2), 3)
        expect(
            "initial sets: back MEV 10 over 2 sessions x 1 exercise",
            Progression.initialSetsPerExercise(muscle: .back, sessionsPerWeek: 2, exercisesInSession: 1), 5)
        expect(
            "initial sets: quads MEV 8 in one session",
            Progression.initialSetsPerExercise(muscle: .quads, sessionsPerWeek: 1, exercisesInSession: 1), 8)
        expect(
            "initial sets: side delts MEV 8 over 3 sessions",
            Progression.initialSetsPerExercise(muscle: .sideDelts, sessionsPerWeek: 3, exercisesInSession: 1), 3)
        expect(
            "initial sets: floor of 2 per exercise",
            Progression.initialSetsPerExercise(muscle: .hamstrings, sessionsPerWeek: 2, exercisesInSession: 2), 2)
        expect(
            "initial sets: MEV 0 still gets 2",
            Progression.initialSetsPerExercise(muscle: .glutes, sessionsPerWeek: 1, exercisesInSession: 1), 2)
    }

    func next(
        _ previous: [SetTarget], _ logged: [LoggedSet?], rir: (Int, Int) = (3, 2),
        range: ClosedRange<Int> = 8...12, increment: Double = 5, offset: Double = 0, sets: Int? = nil
    ) -> [SetTarget] {
        Progression.nextTargets(
            previousTargets: previous, logged: logged, previousRIR: rir.0, targetRIR: rir.1,
            repRange: range, increment: increment, offset: offset, setCount: sets ?? previous.count)
    }

    func testNextTargets() {
        expect(
            "nextTargets adds the freed rep at the same load",
            next([t(100, 10), t(100, 10)], [log(100, 10), log(100, 9)]), [t(100, 11), t(100, 10)])
        expect(
            "nextTargets builds on reps beyond the target",
            next([t(100, 9)], [log(100, 10)]), [t(100, 11)])
        expect(
            "nextTargets holds load at the top of the range",
            next([t(100, 11)], [log(100, 11)], rir: (1, 0)), [t(100, 12)])
        expect(
            "nextTargets bumps load past the range top and re-solves reps",
            next([t(100, 12)], [log(100, 12)], rir: (1, 0)), [t(105, 10)])
        expect(
            "nextTargets rounds an off-grid bumped load down to the increment",
            next([t(102.5, 12)], [log(102.5, 12)], rir: (1, 0)), [t(105, 11)])
        expect(
            "nextTargets clamps re-solved reps to the range bottom",
            next([t(20, 12)], [log(20, 12)], rir: (1, 0)), [t(25, 8)])
        expect(
            "nextTargets repeats a target missed by 2",
            next([t(100, 10)], [log(100, 8)]), [t(100, 10)])
        expect(
            "nextTargets progresses a target missed by 1",
            next([t(100, 10)], [log(100, 9)], rir: (3, 1)), [t(100, 11)])
        expect(
            "nextTargets repeats the target when the log is nil",
            next([t(100, 10), t(100, 10)], [log(100, 10), nil]), [t(100, 11), t(100, 10)])
        expect(
            "nextTargets repeats the target when the log is missing",
            next([t(100, 10), t(100, 10)], [log(100, 10)]), [t(100, 11), t(100, 10)])
        expect(
            "nextTargets keeps calibrating with no log",
            next([.calibrate], [nil]), [.calibrate])
        expect(
            "nextTargets turns a calibration log into a target",
            next([.calibrate], [log(60, 10)]), [t(60, 11)])
        expect(
            "nextTargets bodyweight just adds reps, even past the range",
            next([t(0, 12)], [log(0, 14)], rir: (2, 1), increment: 0), [t(0, 15)])
        expect(
            "nextTargets holds reps at an unchanged RIR",
            next([t(100, 10)], [log(100, 10)], rir: (3, 3)), [t(100, 10)])
        expect(
            "nextTargets added sets copy the last set",
            next([t(100, 10), t(95, 10)], [log(100, 10), log(95, 10)], sets: 3), [t(100, 11), t(95, 11), t(95, 11)])
        expect(
            "nextTargets removed sets drop from the end",
            next([t(100, 10), t(95, 10)], [log(100, 10), log(95, 10)], sets: 1), [t(100, 11)])
    }

    func testDeload() {
        let firstWeek = [t(100, 10), t(100, 10), t(100, 9)]
        expect(
            "deload halves 5 sets to 3 at week-1 targets",
            Progression.deloadTargets(firstWeek: firstWeek, lastAccumulationSetCount: 5), firstWeek)
        expect(
            "deload halves 4 sets to 2",
            Progression.deloadTargets(firstWeek: firstWeek, lastAccumulationSetCount: 4), [t(100, 10), t(100, 10)])
        expect(
            "deload pads with the last week-1 target",
            Progression.deloadTargets(firstWeek: [t(100, 10), t(95, 10)], lastAccumulationSetCount: 7),
            [t(100, 10), t(95, 10), t(95, 10), t(95, 10)])
        expect(
            "deload keeps at least one set",
            Progression.deloadTargets(firstWeek: firstWeek, lastAccumulationSetCount: 1), [t(100, 10)])
    }

    func testOneRepMax() {
        expectClose("e1RM 100 x 10", Progression.estimatedOneRepMax(weight: 100, reps: 10), 133.33)
        expectClose("e1RM counts RIR as reps", Progression.estimatedOneRepMax(weight: 100, reps: 8, rir: 2), 133.33)
        expectClose("e1RM single", Progression.estimatedOneRepMax(weight: 200, reps: 1), 206.67)
        expect(
            "load for 9 reps at 3 RIR from a 133 e1RM",
            Progression.load(forReps: 9, rir: 3, oneRepMax: 400.0 / 3, increment: 5, offset: 0), 95)
        expect("reps at 95 with 3 RIR from a 133 e1RM", Progression.reps(atLoad: 95, rir: 3, oneRepMax: 400.0 / 3), 9)
        expect("starting reps sit between bottom and middle (8-12)", Progression.startingReps(in: 8...12), 9)
        expect("starting reps sit between bottom and middle (12-20)", Progression.startingReps(in: 12...20), 14)
    }
}
