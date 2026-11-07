import SwiftData
import XCTest

@testable import FFiveCore

@MainActor
final class PlannerTests: XCTestCase {
    func expect<T: Equatable>(
        _ name: String, _ actual: T, _ expected: T, file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertEqual(actual, expected, name, file: file, line: line)
    }

    let day: TimeInterval = 86_400
    let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    func snapshot(_ context: ModelContext) -> PlanningSnapshot { PlanningSnapshot(context: context) }

    func testMesocycleLifecycle() {
        let context = ModelContext(AppStore.makeContainer(inMemory: true))

        let history = Workout(name: "Old session", startDate: t0 - 10 * day)
        context.insert(history)
        let row = Exercise(name: "Barbell Row", order: 0, muscle: .back)
        history.exercises.append(row)
        let rowSet = SetEntry(reps: 8, weight: 200, order: 0)
        rowSet.status = .done
        row.sets.append(rowSet)
        history.endDate = t0 - 10 * day + 3600

        var draft = MesoDraft(template: nil)
        draft.days = [
            .init(
                name: "A",
                slots: [
                    .init(exercise: "Bench Press", muscle: .chest), .init(exercise: "Cable Fly", muscle: .chest),
                    .init(exercise: "Lat Pulldown", muscle: .back), .init(exercise: "Calf Raise", muscle: .calves),
                ]),
            .init(
                name: "B",
                slots: [
                    .init(exercise: "Incline Dumbbell Press", muscle: .chest),
                    .init(exercise: "Barbell Row", muscle: .back),
                ]),
            .init(name: "Empty", slots: []),
        ]
        let meso = MesoPlanner.start(draft, in: context)
        expect("start drops days with no exercises", meso.days.count, 2)

        func session(_ week: Int, _ dayIndex: Int, at date: Date) -> Workout {
            let workout = MesoPlanner.workout(
                for: meso, at: SessionKey(week: week, dayIndex: dayIndex), unit: .lb,
                snapshot: snapshot(context), in: context)
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
                    set.status = .done
                }
            }
        }
        let calibration: [String: (Double, Int)] = [
            "Bench Press": (100, 10), "Cable Fly": (30, 12), "Lat Pulldown": (120, 10),
            "Calf Raise": (150, 12), "Incline Dumbbell Press": (40, 10),
        ]

        let w0a = session(0, 0, at: t0)
        expect(
            "week 1 sets split MEV over sessions and exercises",
            counts(w0a), ["Bench Press": 3, "Cable Fly": 3, "Lat Pulldown": 5, "Calf Raise": 8])
        expect("week 1 with no history calibrates", Set(targets(w0a, "Bench Press")), [SetTarget.calibrate])
        expect(
            "calibrate sets prefill zero", w0a.exercises.flatMap(\.sets).allSatisfy { $0.weight == 0 && $0.reps == 0 },
            true)
        expect("workout(for:) returns the stored session", session(0, 0, at: t0) === w0a, true)
        expect("workout(for:) never duplicates a session", meso.workouts.count, 1)

        log(w0a, calibration)
        w0a.updateFeedback(for: .chest) {
            $0 = MuscleFeedback(pump: .moderate, workload: .easy, jointPain: JointPain.none)
        }
        w0a.updateFeedback(for: .back) {
            $0 = MuscleFeedback(pump: .moderate, workload: .good, jointPain: JointPain.none)
        }
        w0a.updateFeedback(for: .calves) {
            $0 = MuscleFeedback(pump: .moderate, workload: .easy, jointPain: JointPain.none)
        }
        w0a.finish(in: context)
        expect("next up moves to day 2 after day 1 finishes", meso.nextUp, SessionKey(week: 0, dayIndex: 1))

        let w0b = session(0, 1, at: t0 + 2 * day)
        expect(
            "week 1 load comes from the latest e1RM in history (200x8 -> 190x7 at 3 RIR)",
            Set(targets(w0b, "Barbell Row")), [SetTarget(weight: 190, reps: 7)])
        let pendingB = w0b.pendingSoreness
        expect("soreness is asked for muscles trained earlier", Set(pendingB.keys), [.chest, .back])
        MesoPlanner.recordSoreness(
            .never, on: pendingB[.chest]!, during: w0b, unit: .lb, snapshot: snapshot(context), in: context)
        MesoPlanner.recordSoreness(
            .healedOnTime, on: pendingB[.back]!, during: w0b, unit: .lb, snapshot: snapshot(context), in: context)
        expect(
            "soreness is written back to the earlier session", w0a.feedbackRecord(for: .chest)?.value.soreness, .never)
        expect("answered soreness is no longer pending", w0b.pendingSoreness.isEmpty, true)
        log(w0b, calibration)
        w0b.updateFeedback(for: .chest) {
            $0 = MuscleFeedback(pump: .moderate, workload: .easy, jointPain: JointPain.none)
        }
        w0b.finish(in: context)

        let doneW0 = MesoPlanner.weeklyVolume(meso, week: 0, unit: .lb, snapshot: snapshot(context)).first {
            $0.muscle == .chest
        }
        expect("weekly volume counts done chest sets across both days", doneW0?.done, 11)

        let w1a = session(1, 0, at: t0 + 7 * day)
        expect(
            "week 2 adds chest sets smallest-first from never-sore + easy (+3)",
            counts(w1a)["Bench Press"].map { [$0, counts(w1a)["Cable Fly"]!] }, [5, 4])
        expect("week 2 holds back sets after healed-on-time + good (0)", counts(w1a)["Lat Pulldown"], 5)
        expect(
            "week 2 bumps load past the rep range top and re-solves reps (100x10 in 5-10 -> 105x8)",
            Set(targets(w1a, "Bench Press")), [SetTarget(weight: 105, reps: 8)])
        expect(
            "week 2 adds the freed rep at the same load (120x10 -> 120x11)",
            Set(targets(w1a, "Lat Pulldown")), [SetTarget(weight: 120, reps: 11)])
        expect("calves wait for soreness before progressing", counts(w1a)["Calf Raise"], 8)

        let pendingW1A = w1a.pendingSoreness
        let calves = pendingW1A[.calves]
        expect("once-a-week muscles ask for soreness from last week's same day", calves?.workout === w0a, true)
        expect("twice-a-week muscles ask about the most recent session", pendingW1A[.chest]?.workout === w0b, true)
        MesoPlanner.recordSoreness(
            .never, on: pendingW1A[.chest]!, during: w1a, unit: .lb, snapshot: snapshot(context), in: context)
        expect("soreness for another day's session leaves this plan alone", counts(w1a)["Bench Press"], 5)
        MesoPlanner.recordSoreness(
            .never, on: calves!, during: w1a, unit: .lb, snapshot: snapshot(context), in: context)
        expect(
            "answering soreness re-plans the untouched muscle (never sore + easy -> +3)", counts(w1a)["Calf Raise"], 11)

        let bench = w1a.sortedExercises.first { $0.name == "Bench Press" }!
        for set in bench.sortedSets.dropLast() { set.status = .done }
        w1a.finish(in: context)
        expect("finishing a block session keeps undone sets for next week", bench.sets.count, 5)
        expect("next up moves to week 2 day 2", meso.nextUp, SessionKey(week: 1, dayIndex: 1))

        for _ in 0..<6 { bench.sets.append(SetEntry(target: SetTarget(weight: 105, reps: 8), order: bench.sets.count)) }
        let w1b = session(1, 1, at: t0 + 9 * day)
        expect(
            "adds stop at MRV counting sets already planned this week (+3 wanted, room 22 - 15 - 5 = 2)",
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
        let lastBench = meso.workout(at: SessionKey(week: 3, dayIndex: 0))!.sortedExercises.first {
            $0.name == "Bench Press"
        }!
        let deload = session(4, 0, at: t0 + 29 * day)
        expect("deload is week 5 of a 4-week block", deload.phase, .deload)
        expect(
            "deload halves last week's sets, rounded up", counts(deload)["Bench Press"], (lastBench.sets.count + 1) / 2)
        expect(
            "deload returns to week-1 loads and reps", Set(targets(deload, "Bench Press")),
            [SetTarget(weight: 100, reps: 10)])
        deload.finish(in: context)
        let lastDay = session(4, 1, at: t0 + 31 * day)
        lastDay.finish(in: context)
        expect("next up is nil once the deload is done", meso.nextUp, nil)
    }

    @MainActor private final class Block {
        let context = ModelContext(AppStore.makeContainer(inMemory: true))
        let meso: Mesocycle

        init() {
            var draft = MesoDraft(template: nil)
            draft.days = [
                .init(
                    name: "A",
                    slots: [
                        .init(exercise: "Bench Press", muscle: .chest),
                        .init(exercise: "Lat Pulldown", muscle: .back),
                        .init(exercise: "Calf Raise", muscle: .calves),
                    ])
            ]
            meso = MesoPlanner.start(draft, in: context)
        }

        func session(_ week: Int) -> Workout {
            MesoPlanner.workout(
                for: meso, at: SessionKey(week: week, dayIndex: 0), unit: .lb,
                snapshot: PlanningSnapshot(context: context), in: context)
        }

        func reorder(_ workout: Workout, to names: [String], _ scope: PlanScope) {
            MesoPlanner.reorder(
                workout, to: names.map { name in workout.exercises.first { $0.name == name }! }, scope: scope)
        }

        func swap(_ workout: Workout, _ from: String, to name: String, _ scope: PlanScope) {
            MesoPlanner.swap(
                workout.exercises.first { $0.name == from }!, to: name, muscle: .chest, scope: scope, unit: .lb,
                snapshot: PlanningSnapshot(context: context), in: context)
        }

        func finish(_ workout: Workout) {
            for set in workout.exercises.flatMap(\.sets) {
                set.weight = set.targetWeight ?? 100
                set.reps = set.targetReps ?? 10
                set.status = .done
            }
            workout.finish(in: context)
        }
    }

    private let original = ["Bench Press", "Lat Pulldown", "Calf Raise"]
    private let reordered = ["Calf Raise", "Bench Press", "Lat Pulldown"]

    private func names(_ workout: Workout) -> [String] { workout.sortedExercises.map(\.name) }

    private let swapped = ["Incline Dumbbell Press", "Lat Pulldown", "Calf Raise"]

    func testSwapThisSessionOnly() {
        let block = Block()
        let week0 = block.session(0)
        block.swap(week0, "Bench Press", to: "Incline Dumbbell Press", .thisSession)
        expect("swap: this session shows the new exercise", names(week0), swapped)
        block.finish(week0)
        let week1 = block.session(1)
        expect("swap: week 2 keeps the original exercise", names(week1), original)
        block.finish(week1)
        expect("swap: week 3 keeps the original exercise", names(block.session(2)), original)
    }

    func testSwapThisSessionResumesTheOriginalsProgression() {
        let block = Block()
        let week0 = block.session(0)
        block.finish(week0)
        let lastBench = week0.exercises.first { $0.name == "Bench Press" }!.sortedSets.map(\.weight).max()!
        let week1 = block.session(1)
        block.swap(week1, "Bench Press", to: "Incline Dumbbell Press", .thisSession)
        block.finish(week1)
        let bench = block.session(2).exercises.first { $0.name == "Bench Press" }!
        expect(
            "swap: week 3 progresses the original from its week 1 load",
            bench.sortedSets.allSatisfy { ($0.targetWeight ?? 0) >= lastBench && $0.targetReps != nil }, true)
    }

    func testSwapThisSessionTwiceKeepsLaterWeeksOriginal() {
        let block = Block()
        let week0 = block.session(0)
        block.swap(week0, "Bench Press", to: "Incline Dumbbell Press", .thisSession)
        block.swap(week0, "Incline Dumbbell Press", to: "Cable Fly", .thisSession)
        block.finish(week0)
        expect("swap: a second session-only swap still leaves later weeks alone", names(block.session(1)), original)
    }

    func testSwapLaterWeeksCarriesForward() {
        let block = Block()
        let week0 = block.session(0)
        block.swap(week0, "Bench Press", to: "Incline Dumbbell Press", .thisSession)
        block.swap(week0, "Incline Dumbbell Press", to: "Incline Dumbbell Press", .laterWeeks)
        block.finish(week0)
        let week1 = block.session(1)
        expect("swap: week 2 is planned with the new exercise", names(week1), swapped)
        block.finish(week1)
        expect("swap: week 3 is planned with the new exercise", names(block.session(2)), swapped)
    }

    func testSwapScopeAndBuiltLaterWeeks() {
        for (scope, expected) in [(PlanScope.laterWeeks, swapped), (.thisSession, original)] {
            let block = Block()
            block.finish(block.session(0))
            let week1 = block.session(1)
            let week2 = block.session(2)
            block.swap(week1, "Bench Press", to: "Incline Dumbbell Press", scope)
            expect("swap \(scope): a built, unstarted later week", names(week2), expected)
        }
    }

    func testReorderQuickWorkout() {
        let context = ModelContext(AppStore.makeContainer(inMemory: true))
        let quick = Workout(name: "Quick")
        context.insert(quick)
        for (order, name) in original.enumerated() { quick.exercises.append(Exercise(name: name, order: order)) }
        MesoPlanner.reorder(
            quick, to: reordered.map { name in quick.exercises.first { $0.name == name }! }, scope: .thisSession)
        try! context.save()
        expect("reorder: a quick workout shows the new order", names(quick), reordered)
        let fetched = try! context.fetch(FetchDescriptor<Workout>())
        expect("reorder: a quick workout keeps the new order in the store", fetched.first.map(names), reordered)
    }

    func testReorderLaterWeeksCarriesForward() {
        let block = Block()
        let week0 = block.session(0)
        block.reorder(week0, to: reordered, .laterWeeks)
        block.finish(week0)
        expect("reorder: week 1 shows the new order", names(week0), reordered)
        expect("reorder: week 2 is planned in the new order", names(block.session(1)), reordered)
    }

    func testReorderThisSessionOnly() {
        let block = Block()
        let week0 = block.session(0)
        block.reorder(week0, to: reordered, .thisSession)
        block.finish(week0)
        expect("reorder: this session shows the new order", names(week0), reordered)
        let week1 = block.session(1)
        expect("reorder: week 2 keeps the original order", names(week1), original)
        block.finish(week1)
        expect("reorder: week 3 keeps the original order", names(block.session(2)), original)
    }

    func testReorderThisSessionTwiceKeepsLaterWeeksOriginal() {
        let block = Block()
        let week0 = block.session(0)
        block.reorder(week0, to: reordered, .thisSession)
        block.reorder(week0, to: ["Lat Pulldown", "Calf Raise", "Bench Press"], .thisSession)
        block.finish(week0)
        expect(
            "reorder: a second session-only reorder still leaves later weeks alone", names(block.session(1)), original)
    }

    func testReorderLaterWeeksReachesBuiltUnstartedWeek() {
        let block = Block()
        let week0 = block.session(0)
        block.finish(week0)
        let week1 = block.session(1)
        let week2 = week1
        block.reorder(week0, to: reordered, .laterWeeks)
        expect("reorder: a built, unstarted later week follows", names(week2), reordered)
    }

    func testReorderLeavesFinishedLaterWeeksAlone() {
        let block = Block()
        let week0 = block.session(0)
        block.finish(week0)
        let week1 = block.session(1)
        block.finish(week1)
        block.reorder(week0, to: reordered, .laterWeeks)
        expect("reorder: a finished later week keeps what was done", names(week1), original)
    }

    func testReorderIsTotal() {
        let block = Block()
        let week0 = block.session(0)
        let stranger = Exercise(name: "Squat", order: 0)
        let calves = week0.exercises.first { $0.name == "Calf Raise" }!
        MesoPlanner.reorder(week0, to: [calves, stranger, calves], scope: .laterWeeks)
        expect(
            "reorder: unlisted exercises follow, strangers and repeats are ignored", names(week0),
            ["Calf Raise", "Bench Press", "Lat Pulldown"])
    }

    func testReorderDoesNotChangeProgression() {
        func run(reorder scope: PlanScope?) -> [String: [SetTarget]] {
            let block = Block()
            let week0 = block.session(0)
            if let scope { block.reorder(week0, to: reordered, scope) }
            block.finish(week0)
            let week1 = block.session(1)
            return Dictionary(uniqueKeysWithValues: week1.exercises.map { ($0.name, $0.sortedSets.map(\.target)) })
        }
        let untouched = run(reorder: nil)
        expect("reorder: later-weeks reorder keeps every exercise's targets", run(reorder: .laterWeeks), untouched)
        expect("reorder: this-session reorder keeps every exercise's targets", run(reorder: .thisSession), untouched)
    }

    func testSkip() {
        let context = ModelContext(AppStore.makeContainer(inMemory: true))
        var draft = MesoDraft(template: nil)
        draft.days = [
            .init(
                name: "A",
                slots: [.init(exercise: "Bench Press", muscle: .chest), .init(exercise: "Lat Pulldown", muscle: .back)]),
            .init(
                name: "B",
                slots: [
                    .init(exercise: "Incline Dumbbell Press", muscle: .chest),
                    .init(exercise: "Barbell Row", muscle: .back),
                ]),
        ]
        let meso = MesoPlanner.start(draft, in: context)
        let loads: [String: (Double, Int)] = [
            "Bench Press": (100, 6), "Lat Pulldown": (120, 8), "Incline Dumbbell Press": (40, 10),
            "Barbell Row": (150, 8),
        ]
        func key(_ week: Int, _ dayIndex: Int) -> SessionKey { SessionKey(week: week, dayIndex: dayIndex) }
        func session(_ week: Int, _ dayIndex: Int) -> Workout {
            MesoPlanner.workout(for: meso, at: key(week, dayIndex), unit: .lb, snapshot: snapshot(context), in: context)
        }
        func log(_ workout: Workout) {
            for exercise in workout.exercises {
                for set in exercise.sets {
                    (set.weight, set.reps) = set.targetWeight.map { ($0, set.targetReps ?? 0) } ?? loads[exercise.name]!
                    set.status = .done
                }
            }
        }
        func planned(_ week: Int, _ dayIndex: Int, _ name: String) -> Int? {
            MesoPlanner.plan(meso, at: key(week, dayIndex), unit: .lb, snapshot: snapshot(context)).first {
                $0.name == name
            }?.targets.count
        }
        func targets(_ workout: Workout, _ name: String) -> Set<SetTarget> {
            Set(workout.sortedExercises.first { $0.name == name }!.sortedSets.map(\.target))
        }

        let w0a = session(0, 0)
        let bench = w0a.sortedExercises.first { $0.name == "Bench Press" }!
        for _ in 0..<10 { bench.sets.append(SetEntry(reps: 0, weight: 0, order: bench.sets.count)) }
        log(w0a)
        w0a.finish(in: context)
        let w0b = session(0, 1)
        log(w0b)
        w0b.updateFeedback(for: .chest) {
            $0 = MuscleFeedback(soreness: .never, pump: .moderate, workload: .easy, jointPain: JointPain.none)
        }
        w0b.finish(in: context)
        expect("skip: week 2 day 1 is next once week 1 is done", meso.nextUp, key(1, 0))
        expect(
            "skip: day 1's 15 chest sets cap day 2's +3 at MRV (22 - 15 - 5 = 2)",
            planned(1, 1, "Incline Dumbbell Press"), 7)

        let w1a = session(1, 0)
        meso.skip(key(1, 0), in: context)
        expect("skip: skipping advances next up", meso.nextUp, key(1, 1))
        expect(
            "skip: skipping an untouched in-progress session deletes its workout",
            meso.workout(at: key(1, 0)) == nil && w1a.isDeleted, true)
        expect("skip: the skipped key reads as skipped", meso.status(at: key(1, 0)), .skipped)
        meso.skip(key(1, 0), in: context)
        expect("skip: skipping twice records the key once", meso.skippedSessions, [key(1, 0)])
        expect("skip: the skipped day frees its MRV room (+3 in full)", planned(1, 1, "Incline Dumbbell Press"), 8)
        let chest = MesoPlanner.weeklyVolume(meso, week: 1, unit: .lb, snapshot: snapshot(context)).first {
            $0.muscle == .chest
        }
        expect("skip: weekly volume counts the skipped day as 0 sets", chest.map { [$0.planned, $0.done] }, [8, 0])

        let w1b = session(1, 1)
        w1b.sortedExercises[0].sortedSets[0].status = .done
        meso.skip(key(1, 1), in: context)
        expect("skip: refused once a set is done", meso.status(at: key(1, 1)), .inProgress(w1b))
        meso.skip(key(0, 0), in: context)
        expect("skip: refused for a finished session", meso.status(at: key(0, 0)), .finished(w0a))
        expect("skip: refusals record nothing", meso.skippedSessions, [key(1, 0)])

        meso.unskip(key(1, 0))
        expect("skip: unskip restores the key as upcoming", meso.status(at: key(1, 0)), .upcoming)
        expect("skip: an unskipped earlier day is next up again", meso.nextUp, key(1, 0))
        meso.skip(key(1, 0), in: context)
        log(w1b)
        w1b.finish(in: context)

        let w2a = session(2, 0)
        expect(
            "skip: the day after a skip builds from the last real session, 3 -> 1 RIR adds 2 reps (100x6 -> 100x8)",
            targets(w2a, "Bench Press"), [SetTarget(weight: 100, reps: 8)])
        expect(
            "skip: the same two-week drop on a second lift (120x8 -> 120x10)",
            targets(w2a, "Lat Pulldown"), [SetTarget(weight: 120, reps: 10)])

        for remaining in meso.allKeys { meso.skip(remaining, in: context) }
        expect("skip: skipping every remaining session completes the block", meso.nextUp, nil)
        expect("skip: finished sessions survive skipping the rest", meso.workouts.filter(\.isFinished).count, 3)
    }

    func testMovedDaysTrainInTheirNewOrder() {
        let context = ModelContext(AppStore.makeContainer(inMemory: true))
        var draft = MesoDraft(template: nil)
        draft.days = [
            .init(name: "Push", weekday: .monday, slots: [.init(exercise: "Bench Press", muscle: .chest)]),
            .init(name: "Pull", weekday: .wednesday, slots: [.init(exercise: "Barbell Row", muscle: .back)]),
            .init(name: "Legs", weekday: .friday, slots: [.init(exercise: "Calf Raise", muscle: .calves)]),
        ]
        draft.moveDays(fromOffsets: [2], toOffset: 0)
        expect("drag up", draft.days.map(\.name), ["Legs", "Push", "Pull"])
        draft.moveDays(fromOffsets: [0], toOffset: 2)
        expect("drag down", draft.days.map(\.name), ["Push", "Legs", "Pull"])
        draft.moveDays(fromOffsets: [1], toOffset: 1)
        expect("drop in place", draft.days.map(\.name), ["Push", "Legs", "Pull"])
        draft.moveDays(fromOffsets: [0, 2], toOffset: 3)
        expect("drag several to the end", draft.days.map(\.name), ["Legs", "Push", "Pull"])

        let meso = MesoPlanner.start(draft, in: context)
        expect("block days follow the draft", meso.dayNames, ["Legs", "Push", "Pull"])
        expect("weekdays move with their days", meso.weekdays, [.friday, .monday, .wednesday])
        expect("the moved day trains first", meso.nextUp, SessionKey(week: 0, dayIndex: 0))
        let first = MesoPlanner.workout(
            for: meso, at: SessionKey(week: 0, dayIndex: 0), unit: .lb, snapshot: snapshot(context), in: context)
        expect("first session holds the moved day's exercises", first.sortedExercises.map(\.name), ["Calf Raise"])
    }

    func testMusclePriorities() {
        let context = ModelContext(AppStore.makeContainer(inMemory: true))
        var draft = MesoDraft(template: nil)
        draft.days = [
            .init(
                name: "A",
                slots: [
                    .init(exercise: "Bench Press", muscle: .chest), .init(exercise: "Lat Pulldown", muscle: .back),
                    .init(exercise: "Leg Extension", muscle: .quads),
                ])
        ]
        draft.priorities = [.chest: .maintain, .back: .emphasize, .biceps: .maintain]
        expect("draft lists its trained muscles in catalog order", draft.muscles, [.chest, .back, .quads])
        let meso = MesoPlanner.start(draft, in: context)
        expect("start keeps the trained muscles' priorities", meso.priority(of: .chest), .maintain)
        expect("start keeps emphasis", meso.priority(of: .back), .emphasize)
        expect("an unset muscle is normal", meso.priority(of: .quads), .normal)
        expect("start drops priorities for muscles no day trains", meso.priority(of: .biceps), .normal)
        expect("only non-normal priorities are stored", meso.musclePriorityRaw.count, 2)

        func key(_ week: Int) -> SessionKey { SessionKey(week: week, dayIndex: 0) }
        func planned(_ week: Int) -> [String: Int] {
            Dictionary(
                uniqueKeysWithValues: MesoPlanner.plan(meso, at: key(week), unit: .lb, snapshot: snapshot(context)).map
                {
                    ($0.name, $0.targets.count)
                })
        }
        expect(
            "week 1: maintained chest starts at MV 8, emphasized back and normal quads at MEV",
            planned(0), ["Bench Press": 8, "Lat Pulldown": 10, "Leg Extension": 8])

        let w0 = MesoPlanner.workout(for: meso, at: key(0), unit: .lb, snapshot: snapshot(context), in: context)
        for exercise in w0.exercises {
            for set in exercise.sets {
                (set.weight, set.reps) = (100, 10)
                set.status = .done
            }
        }
        for muscle in [Muscle.chest, .back, .quads] {
            w0.updateFeedback(for: muscle) {
                $0 = MuscleFeedback(soreness: .healedEarly, pump: .moderate, workload: .good, jointPain: JointPain.none)
            }
        }
        w0.finish(in: context)
        expect(
            "week 2 on the same +1 feedback: maintain holds, emphasize adds 2, normal adds 1",
            planned(1), ["Bench Press": 8, "Lat Pulldown": 12, "Leg Extension": 9])

        meso.setPriority(.normal, of: .chest)
        expect("a priority change re-plans the next unbuilt week", planned(1)["Bench Press"], 9)
        expect("setting normal clears the stored entry", meso.musclePriorityRaw[Muscle.chest.rawValue], nil)
    }

    func testStore() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("planner-\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: url) }
        func open() -> ModelContext {
            ModelContext(
                try! ModelContainer(
                    for: AppStore.schema, configurations: ModelConfiguration(schema: AppStore.schema, url: url)))
        }

        let writer = open()
        var draft = MesoDraft(template: nil)
        draft.days = [
            .init(name: "A", slots: [.init(exercise: "Bench Press", muscle: .chest)]),
            .init(name: "B", slots: [.init(exercise: "Barbell Row", muscle: .back)]),
        ]
        let meso = MesoPlanner.start(draft, in: writer)
        meso.skip(SessionKey(week: 0, dayIndex: 1), in: writer)
        meso.skip(SessionKey(week: 1, dayIndex: 0), in: writer)
        try! writer.save()

        let reopened = (try? open().fetch(FetchDescriptor<Mesocycle>())) ?? []
        expect(
            "store: skipped sessions survive a save and reopen on disk",
            reopened.first?.skippedSessions, [SessionKey(week: 0, dayIndex: 1), SessionKey(week: 1, dayIndex: 0)])
        expect(
            "store: a reopened block reads the skip as its status",
            reopened.first?.status(at: SessionKey(week: 0, dayIndex: 1)), .skipped)

        let noted = Workout(name: "Noted day")
        noted.setNote("  Felt strong  ", pinned: false)
        writer.insert(noted)
        let bench = Exercise(name: "Bench Press", order: 0)
        noted.exercises.append(bench)
        bench.setNote("Elbows in", in: writer)
        PinnedNote.set("Seat Level: 4", for: "Bench Press", in: writer)
        try! writer.save()
        let second = open()
        let days = (try? second.fetch(FetchDescriptor<Workout>())) ?? []
        expect(
            "store: a day note survives a save and reopen on disk", days.first { $0.name == "Noted day" }?.note,
            "Felt strong")
        expect(
            "store: a pinned note survives a save and reopen on disk",
            PinnedNote.find(named: "Bench Press", in: second)?.text, "Seat Level: 4")
    }

    func testEnd() {
        let context = ModelContext(AppStore.makeContainer(inMemory: true))
        var draft = MesoDraft(template: nil)
        draft.days = [
            .init(name: "A", slots: [.init(exercise: "Bench Press", muscle: .chest)]),
            .init(name: "B", slots: [.init(exercise: "Barbell Row", muscle: .back)]),
        ]
        let meso = MesoPlanner.start(draft, in: context)
        let started = MesoPlanner.workout(
            for: meso, at: SessionKey(week: 0, dayIndex: 0), unit: .lb, snapshot: .empty, in: context)
        started.sortedExercises[0].sortedSets[0].status = .done
        let untouched = MesoPlanner.workout(
            for: meso, at: SessionKey(week: 0, dayIndex: 1), unit: .lb, snapshot: .empty, in: context)

        meso.end(in: context)
        expect("end: the block gets a finished date", meso.finishedDate != nil, true)
        expect("end: an open session with a logged set is finished so it reaches history", started.isFinished, true)
        expect("end: its logged set is kept", started.completedSets, 1)
        expect(
            "end: an untouched open session is dropped",
            untouched.isDeleted && meso.workout(at: SessionKey(week: 0, dayIndex: 1)) == nil, true)
    }

    func testSnapshotMatchesPerExerciseFetch() {
        let context = ModelContext(AppStore.makeContainer(inMemory: true))
        let catalog = ExerciseCatalog.all

        func oracle(_ name: String) -> Double? {
            let descriptor = FetchDescriptor<Exercise>(predicate: #Predicate { $0.name == name })
            let matches = (try? context.fetch(descriptor)) ?? []
            return
                matches
                .compactMap { exercise in
                    exercise.strongestSet.map {
                        (date: exercise.workout?.startDate ?? .distantPast, value: $0.oneRepMax)
                    }
                }
                .max { $0.date < $1.date }?
                .value
        }
        func seed(_ workout: Workout, done: Bool, load: (Int) -> (Double, Int)) {
            workout.bodyweight = 150
            for (order, info) in catalog.enumerated() {
                let exercise = Exercise(name: info.name, order: order, muscle: info.muscle)
                workout.exercises.append(exercise)
                for setOrder in 0..<2 {
                    let (weight, reps) = load(order + setOrder)
                    let set = SetEntry(reps: reps, weight: weight, order: setOrder)
                    set.status = done ? .done : .pending
                    exercise.sets.append(set)
                }
            }
        }
        for session in 0..<3 {
            let workout = Workout(name: "Session \(session)", startDate: t0 + Double(session) * day)
            context.insert(workout)
            seed(workout, done: true) { n in (Double(40 + (n * 7 + session * 13) % 120), 4 + (n + session) % 9) }
            workout.endDate = workout.startDate + 3600
        }
        let undone = Workout(name: "Nothing logged", startDate: t0 + 3 * day)
        context.insert(undone)
        seed(undone, done: false) { _ in (300, 10) }
        undone.endDate = undone.startDate + 3600

        var draft = MesoDraft(template: nil)
        draft.days = [.init(name: "A", slots: [.init(exercise: "Bench Press", muscle: .chest)])]
        let meso = MesoPlanner.start(draft, in: context)
        let deload = Workout(name: "Deload", startDate: t0 + 4 * day)
        context.insert(deload)
        deload.week = meso.accumulationWeeks
        deload.dayIndex = 0
        meso.workouts.append(deload)
        seed(deload, done: true) { _ in (400, 10) }
        deload.endDate = deload.startDate + 3600
        expect("the deload session says nothing about strength", deload.effortRIR, nil)

        let before = snapshot(context)
        for info in catalog {
            expect(
                "snapshot matches the per-exercise fetch for \(info.name)", before.latestOneRepMax(of: info.id),
                oracle(info.name))
            expect("history exists for \(info.name)", before.latestOneRepMax(of: info.id) != nil, true)
        }
        for name in ["Mystery Lift", "Nothing"] {
            expect("no history reads nil for \(name)", before.latestOneRepMax(of: ExerciseID(folding: name)), nil)
            expect("the oracle agrees for \(name)", oracle(name), nil)
        }

        let open = Workout(name: "Open", startDate: t0 + 5 * day)
        context.insert(open)
        let bench = Exercise(name: "Bench Press", order: 0, muscle: .chest)
        open.exercises.append(bench)
        let heavy = SetEntry(reps: 10, weight: 500, order: 0)
        heavy.status = .done
        bench.sets.append(heavy)
        let benchID = ExerciseID(folding: "Bench Press")
        expect(
            "an open session's done set moves the per-exercise fetch", oracle("Bench Press"),
            Progression.estimatedOneRepMax(weight: 500, reps: 10, rir: 0))
        expect(
            "but not the snapshot, which reads finished history only",
            snapshot(context).latestOneRepMax(of: benchID), before.latestOneRepMax(of: benchID))

        let twice = Workout(name: "Bench twice", startDate: t0 + 6 * day)
        context.insert(twice)
        for (order, weight) in [(1, 200.0), (0, 60.0)] {
            let exercise = Exercise(name: "Bench Press", order: order, muscle: .chest)
            twice.exercises.append(exercise)
            let set = SetEntry(reps: 8, weight: weight, order: 0)
            set.status = .done
            exercise.sets.append(set)
        }
        twice.endDate = twice.startDate + 3600
        expect(
            "a lift done twice in one session reads its first row in session order, not the heavier",
            snapshot(context).latestOneRepMax(of: benchID), Progression.estimatedOneRepMax(weight: 60, reps: 8, rir: 0))
    }

    func testNote() {
        let context = ModelContext(AppStore.makeContainer(inMemory: true))
        let older = Workout(name: "Older")
        let newer = Workout(name: "Newer")
        context.insert(older)
        context.insert(newer)
        older.exercises.append(Exercise(name: "Bench Press", order: 0))
        newer.exercises.append(Exercise(name: "Bench Press", order: 0))
        let first = older.exercises[0]
        let later = newer.exercises[0]
        let pinnedCount = { (try? context.fetch(FetchDescriptor<PinnedNote>()))?.count }

        first.setNote("  Elbows in \n", in: context)
        expect("note: saved on that workout's exercise, trimmed", first.note, "Elbows in")
        expect("note: not carried to another workout by default", later.note, nil)
        expect("note: not pinned by default", pinnedCount(), 0)

        first.pinNote(in: context)
        expect(
            "pin: the note is found by name from a later workout",
            PinnedNote.find(named: later.name, in: context)?.text, "Elbows in")
        expect("pin: the row copy is cleared so the note shows once", first.note, nil)
        expect("pin: other exercises have none", PinnedNote.find(named: "Barbell Row", in: context)?.text, nil)

        later.setNote("Seat Level: 5", in: context)
        later.setNote("Seat Level: 5", in: context)
        expect(
            "pin: editing a pinned note edits the pin", PinnedNote.find(named: "Bench Press", in: context)?.text,
            "Seat Level: 5")
        expect("pin: setting twice leaves one row", pinnedCount(), 1)
        expect("pin: the edit stays off the row", later.note, nil)

        later.unpinNote(in: context)
        expect("unpin: the note stays on this workout", later.note, "Seat Level: 5")
        expect("unpin: it no longer carries forward", pinnedCount(), 0)

        later.pinNote(in: context)
        later.deleteNote(in: context)
        later.deleteNote(in: context)
        expect("delete: removes the pin, twice over", pinnedCount(), 0)
        expect("delete: and the row note", later.note, nil)
        later.setNote("  \n ", in: context)
        expect("note: blank text stores nil", later.note, nil)

        newer.setNote("  Left shoulder tight \n", pinned: false)
        expect("day note: trimmed on save", newer.note, "Left shoulder tight")
        newer.setNote("   ", pinned: false)
        expect("day note: blank stores nil", newer.note, nil)
    }
}

extension SetTarget: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(weight)
        hasher.combine(reps)
    }
}
