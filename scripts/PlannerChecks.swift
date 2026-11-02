import Foundation
import SwiftData

@main
struct PlannerChecks {
    static var failures = 0
    static var count = 0

    static func expect<T: Equatable>(_ name: String, _ actual: T, _ expected: T) {
        count += 1
        if actual == expected {
            print("PASS \(name)")
        } else {
            failures += 1
            print("FAIL \(name): got \(actual), expected \(expected)")
        }
    }

    static let day: TimeInterval = 86_400
    static let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    @MainActor
    static func main() {
        let context = ModelContext(AppStore.makeContainer(inMemory: true))

        let history = Workout(name: "Old session", startDate: t0 - 10 * day)
        context.insert(history)
        let row = Exercise(name: "Barbell Row", order: 0, muscle: .back)
        history.exercises.append(row)
        let rowSet = SetEntry(reps: 8, weight: 200, order: 0)
        rowSet.isDone = true
        row.sets.append(rowSet)
        history.endDate = t0 - 10 * day + 3600

        var draft = MesoDraft(template: nil)
        draft.days = [
            .init(name: "A", slots: [.init(exercise: "Bench Press", muscle: .chest), .init(exercise: "Cable Fly", muscle: .chest),
                                     .init(exercise: "Lat Pulldown", muscle: .back), .init(exercise: "Calf Raise", muscle: .calves)]),
            .init(name: "B", slots: [.init(exercise: "Incline Dumbbell Press", muscle: .chest), .init(exercise: "Barbell Row", muscle: .back)]),
            .init(name: "Empty", slots: []),
        ]
        let meso = MesoPlanner.start(draft, in: context)
        expect("start drops days with no exercises", meso.days.count, 2)

        func session(_ week: Int, _ dayIndex: Int, at date: Date) -> Workout {
            let workout = MesoPlanner.workout(for: meso, at: SessionKey(week: week, dayIndex: dayIndex), unit: .lb, in: context)
            workout.startDate = date
            return workout
        }
        func counts(_ workout: Workout) -> [String: Int] {
            Dictionary(uniqueKeysWithValues: workout.exercises.map { ($0.name, $0.sets.count) })
        }
        func targets(_ workout: Workout, _ name: String) -> [SetTarget] {
            workout.sortedExercises.first { $0.name == name }!.sortedSets.map(\.target)
        }
        func log(_ workout: Workout, _ loads: [String: (Double, Int)]) {
            for exercise in workout.exercises {
                for set in exercise.sets {
                    let (weight, reps) = set.targetWeight.map { ($0, set.targetReps ?? 0) } ?? loads[exercise.name]!
                    set.weight = weight
                    set.reps = reps
                    set.isDone = true
                }
            }
        }
        let calibration: [String: (Double, Int)] = [
            "Bench Press": (100, 10), "Cable Fly": (30, 12), "Lat Pulldown": (120, 10),
            "Calf Raise": (150, 12), "Incline Dumbbell Press": (40, 10),
        ]

        let w0a = session(0, 0, at: t0)
        expect("week 1 sets split MEV over sessions and exercises",
               counts(w0a), ["Bench Press": 3, "Cable Fly": 3, "Lat Pulldown": 5, "Calf Raise": 8])
        expect("week 1 with no history calibrates", Set(targets(w0a, "Bench Press")), [SetTarget.calibrate])
        expect("calibrate sets prefill zero", w0a.exercises.flatMap(\.sets).allSatisfy { $0.weight == 0 && $0.reps == 0 }, true)
        expect("workout(for:) returns the stored session", session(0, 0, at: t0) === w0a, true)
        expect("workout(for:) never duplicates a session", meso.workouts.count, 1)

        log(w0a, calibration)
        w0a.updateFeedback(for: .chest) { $0 = MuscleFeedback(pump: .moderate, workload: .easy, jointPain: JointPain.none) }
        w0a.updateFeedback(for: .back) { $0 = MuscleFeedback(pump: .moderate, workload: .good, jointPain: JointPain.none) }
        w0a.updateFeedback(for: .calves) { $0 = MuscleFeedback(pump: .moderate, workload: .easy, jointPain: JointPain.none) }
        w0a.finish(in: context)
        expect("next up moves to day 2 after day 1 finishes", meso.nextUp, SessionKey(week: 0, dayIndex: 1))

        let w0b = session(0, 1, at: t0 + 2 * day)
        expect("week 1 load comes from the latest e1RM in history (200x8 -> 190x7 at 3 RIR)",
               Set(targets(w0b, "Barbell Row")), [SetTarget(weight: 190, reps: 7)])
        let pendingB = MesoPlanner.pendingSoreness(for: w0b)
        expect("soreness is asked for muscles trained earlier", Set(pendingB.keys), [.chest, .back])
        MesoPlanner.recordSoreness(.never, on: pendingB[.chest]!, during: w0b, unit: .lb, in: context)
        MesoPlanner.recordSoreness(.healedOnTime, on: pendingB[.back]!, during: w0b, unit: .lb, in: context)
        expect("soreness is written back to the earlier session", w0a.feedbackRecord(for: .chest)?.value.soreness, .never)
        expect("answered soreness is no longer pending", MesoPlanner.pendingSoreness(for: w0b).isEmpty, true)
        log(w0b, calibration)
        w0b.updateFeedback(for: .chest) { $0 = MuscleFeedback(pump: .moderate, workload: .easy, jointPain: JointPain.none) }
        w0b.finish(in: context)

        let doneW0 = MesoPlanner.weeklyVolume(meso, week: 0, unit: .lb, context: context).first { $0.muscle == .chest }
        expect("weekly volume counts done chest sets across both days", doneW0?.done, 11)

        let w1a = session(1, 0, at: t0 + 7 * day)
        expect("week 2 adds chest sets smallest-first from never-sore + easy (+3)",
               counts(w1a)["Bench Press"].map { [$0, counts(w1a)["Cable Fly"]!] }, [5, 4])
        expect("week 2 holds back sets after healed-on-time + good (0)", counts(w1a)["Lat Pulldown"], 5)
        expect("week 2 bumps load past the rep range top and re-solves reps (100x10 in 5-10 -> 105x8)",
               Set(targets(w1a, "Bench Press")), [SetTarget(weight: 105, reps: 8)])
        expect("week 2 adds the freed rep at the same load (120x10 -> 120x11)",
               Set(targets(w1a, "Lat Pulldown")), [SetTarget(weight: 120, reps: 11)])
        expect("calves wait for soreness before progressing", counts(w1a)["Calf Raise"], 8)

        let pendingW1A = MesoPlanner.pendingSoreness(for: w1a)
        let calves = pendingW1A[.calves]
        expect("once-a-week muscles ask for soreness from last week's same day", calves?.workout === w0a, true)
        expect("twice-a-week muscles ask about the most recent session", pendingW1A[.chest]?.workout === w0b, true)
        MesoPlanner.recordSoreness(.never, on: pendingW1A[.chest]!, during: w1a, unit: .lb, in: context)
        expect("soreness for another day's session leaves this plan alone", counts(w1a)["Bench Press"], 5)
        MesoPlanner.recordSoreness(.never, on: calves!, during: w1a, unit: .lb, in: context)
        expect("answering soreness re-plans the untouched muscle (never sore + easy -> +3)", counts(w1a)["Calf Raise"], 11)

        let bench = w1a.sortedExercises.first { $0.name == "Bench Press" }!
        for set in bench.sortedSets.dropLast() { set.isDone = true }
        w1a.finish(in: context)
        expect("finishing a block session keeps undone sets for next week", bench.sets.count, 5)
        expect("next up moves to week 2 day 2", meso.nextUp, SessionKey(week: 1, dayIndex: 1))

        for _ in 0..<6 { bench.sets.append(SetEntry(target: SetTarget(weight: 105, reps: 8), order: bench.sets.count)) }
        let w1b = session(1, 1, at: t0 + 9 * day)
        expect("adds stop at MRV counting sets already planned this week (+3 wanted, room 22 - 15 - 5 = 2)",
               counts(w1b)["Incline Dumbbell Press"], 7)

        log(w1b, calibration)
        w1b.finish(in: context)
        for week in 2...3 {
            for dayIndex in 0...1 {
                let workout = session(week, dayIndex, at: t0 + Double(week * 7 + dayIndex * 2) * day)
                log(workout, calibration)
                workout.finish(in: context)
            }
        }
        let lastBench = meso.workout(at: SessionKey(week: 3, dayIndex: 0))!.sortedExercises.first { $0.name == "Bench Press" }!
        let deload = session(4, 0, at: t0 + 29 * day)
        expect("deload is week 5 of a 4-week block", deload.phase, .deload)
        expect("deload halves last week's sets, rounded up", counts(deload)["Bench Press"], (lastBench.sets.count + 1) / 2)
        expect("deload returns to week-1 loads and reps", Set(targets(deload, "Bench Press")), [SetTarget(weight: 100, reps: 10)])
        deload.finish(in: context)
        let lastDay = session(4, 1, at: t0 + 31 * day)
        lastDay.finish(in: context)
        expect("next up is nil once the deload is done", meso.nextUp, nil)

        print("\(count - failures)/\(count) checks passed")
        exit(failures == 0 ? 0 : 1)
    }
}

extension SetTarget: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(weight)
        hasher.combine(reps)
    }
}
