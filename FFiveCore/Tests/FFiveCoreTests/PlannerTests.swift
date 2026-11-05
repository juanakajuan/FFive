import SwiftData
import XCTest
@testable import FFiveCore

@MainActor
final class PlannerTests: XCTestCase {
    func expect<T: Equatable>(_ name: String, _ actual: T, _ expected: T, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(actual, expected, name, file: file, line: line)
    }

    let day: TimeInterval = 86_400
    let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    func testMesocycleLifecycle() {
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
        let pendingB = w0b.pendingSoreness
        expect("soreness is asked for muscles trained earlier", Set(pendingB.keys), [.chest, .back])
        MesoPlanner.recordSoreness(.never, on: pendingB[.chest]!, during: w0b, unit: .lb, in: context)
        MesoPlanner.recordSoreness(.healedOnTime, on: pendingB[.back]!, during: w0b, unit: .lb, in: context)
        expect("soreness is written back to the earlier session", w0a.feedbackRecord(for: .chest)?.value.soreness, .never)
        expect("answered soreness is no longer pending", w0b.pendingSoreness.isEmpty, true)
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

        let pendingW1A = w1a.pendingSoreness
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
    }

    func testSkip() {
        let context = ModelContext(AppStore.makeContainer(inMemory: true))
        var draft = MesoDraft(template: nil)
        draft.days = [
            .init(name: "A", slots: [.init(exercise: "Bench Press", muscle: .chest), .init(exercise: "Lat Pulldown", muscle: .back)]),
            .init(name: "B", slots: [.init(exercise: "Incline Dumbbell Press", muscle: .chest), .init(exercise: "Barbell Row", muscle: .back)]),
        ]
        let meso = MesoPlanner.start(draft, in: context)
        let loads: [String: (Double, Int)] = [
            "Bench Press": (100, 6), "Lat Pulldown": (120, 8), "Incline Dumbbell Press": (40, 10), "Barbell Row": (150, 8),
        ]
        func key(_ week: Int, _ dayIndex: Int) -> SessionKey { SessionKey(week: week, dayIndex: dayIndex) }
        func session(_ week: Int, _ dayIndex: Int) -> Workout {
            MesoPlanner.workout(for: meso, at: key(week, dayIndex), unit: .lb, in: context)
        }
        func log(_ workout: Workout) {
            for exercise in workout.exercises {
                for set in exercise.sets {
                    (set.weight, set.reps) = set.targetWeight.map { ($0, set.targetReps ?? 0) } ?? loads[exercise.name]!
                    set.isDone = true
                }
            }
        }
        func planned(_ week: Int, _ dayIndex: Int, _ name: String) -> Int? {
            MesoPlanner.plan(meso, at: key(week, dayIndex), unit: .lb, context: context).first { $0.name == name }?.targets.count
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
        w0b.updateFeedback(for: .chest) { $0 = MuscleFeedback(soreness: .never, pump: .moderate, workload: .easy, jointPain: JointPain.none) }
        w0b.finish(in: context)
        expect("skip: week 2 day 1 is next once week 1 is done", meso.nextUp, key(1, 0))
        expect("skip: day 1's 15 chest sets cap day 2's +3 at MRV (22 - 15 - 5 = 2)", planned(1, 1, "Incline Dumbbell Press"), 7)

        let w1a = session(1, 0)
        meso.skip(key(1, 0), in: context)
        expect("skip: skipping advances next up", meso.nextUp, key(1, 1))
        expect("skip: skipping an untouched in-progress session deletes its workout", meso.workout(at: key(1, 0)) == nil && w1a.isDeleted, true)
        expect("skip: the skipped key reads as skipped", meso.status(at: key(1, 0)), .skipped)
        meso.skip(key(1, 0), in: context)
        expect("skip: skipping twice records the key once", meso.skippedSessions, [key(1, 0)])
        expect("skip: the skipped day frees its MRV room (+3 in full)", planned(1, 1, "Incline Dumbbell Press"), 8)
        let chest = MesoPlanner.weeklyVolume(meso, week: 1, unit: .lb, context: context).first { $0.muscle == .chest }
        expect("skip: weekly volume counts the skipped day as 0 sets", chest.map { [$0.planned, $0.done] }, [8, 0])

        let w1b = session(1, 1)
        w1b.sortedExercises[0].sortedSets[0].isDone = true
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
        expect("skip: the day after a skip builds from the last real session, 3 -> 1 RIR adds 2 reps (100x6 -> 100x8)",
               targets(w2a, "Bench Press"), [SetTarget(weight: 100, reps: 8)])
        expect("skip: the same two-week drop on a second lift (120x8 -> 120x10)",
               targets(w2a, "Lat Pulldown"), [SetTarget(weight: 120, reps: 10)])

        for remaining in meso.allKeys { meso.skip(remaining, in: context) }
        expect("skip: skipping every remaining session completes the block", meso.nextUp, nil)
        expect("skip: finished sessions survive skipping the rest", meso.workouts.filter(\.isFinished).count, 3)
    }

    func testStore() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("planner-\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: url) }
        func open() -> ModelContext {
            ModelContext(try! ModelContainer(for: AppStore.schema, configurations: ModelConfiguration(schema: AppStore.schema, url: url)))
        }

        let writer = open()
        var draft = MesoDraft(template: nil)
        draft.days = [.init(name: "A", slots: [.init(exercise: "Bench Press", muscle: .chest)]),
                      .init(name: "B", slots: [.init(exercise: "Barbell Row", muscle: .back)])]
        let meso = MesoPlanner.start(draft, in: writer)
        meso.skip(SessionKey(week: 0, dayIndex: 1), in: writer)
        meso.skip(SessionKey(week: 1, dayIndex: 0), in: writer)
        try! writer.save()

        let reopened = (try? open().fetch(FetchDescriptor<Mesocycle>())) ?? []
        expect("store: skipped sessions survive a save and reopen on disk",
               reopened.first?.skippedSessions, [SessionKey(week: 0, dayIndex: 1), SessionKey(week: 1, dayIndex: 0)])
        expect("store: a reopened block reads the skip as its status",
               reopened.first?.status(at: SessionKey(week: 0, dayIndex: 1)), .skipped)

        let noted = Workout(name: "Noted day")
        noted.setNote("  Felt strong  ")
        writer.insert(noted)
        let bench = Exercise(name: "Bench Press", order: 0)
        noted.exercises.append(bench)
        bench.setNote("Elbows in", in: writer)
        PinnedNote.set("Seat Level: 4", for: "Bench Press", in: writer)
        try! writer.save()
        let second = open()
        let days = (try? second.fetch(FetchDescriptor<Workout>())) ?? []
        expect("store: a day note survives a save and reopen on disk", days.first { $0.name == "Noted day" }?.note, "Felt strong")
        expect("store: a pinned note survives a save and reopen on disk",
               PinnedNote.find(named: "Bench Press", in: second)?.text, "Seat Level: 4")
    }

    func testEnd() {
        let context = ModelContext(AppStore.makeContainer(inMemory: true))
        var draft = MesoDraft(template: nil)
        draft.days = [.init(name: "A", slots: [.init(exercise: "Bench Press", muscle: .chest)]),
                      .init(name: "B", slots: [.init(exercise: "Barbell Row", muscle: .back)])]
        let meso = MesoPlanner.start(draft, in: context)
        let started = MesoPlanner.workout(for: meso, at: SessionKey(week: 0, dayIndex: 0), unit: .lb, in: context)
        started.sortedExercises[0].sortedSets[0].isDone = true
        let untouched = MesoPlanner.workout(for: meso, at: SessionKey(week: 0, dayIndex: 1), unit: .lb, in: context)

        meso.end(in: context)
        expect("end: the block gets a finished date", meso.finishedDate != nil, true)
        expect("end: an open session with a logged set is finished so it reaches history", started.isFinished, true)
        expect("end: its logged set is kept", started.completedSets, 1)
        expect("end: an untouched open session is dropped", untouched.isDeleted && meso.workout(at: SessionKey(week: 0, dayIndex: 1)) == nil, true)
    }

    func testNote() {
        let context = ModelContext(AppStore.makeContainer(inMemory: true))
        let older = Workout(name: "Older")
        let newer = Workout(name: "Newer")
        context.insert(older)
        context.insert(newer)
        older.exercises.append(Exercise(name: "Bench Press", order: 0))
        newer.exercises.append(Exercise(name: "Bench Press", order: 0))
        let first = older.exercises[0], later = newer.exercises[0]
        let pinnedCount = { (try? context.fetch(FetchDescriptor<PinnedNote>()))?.count }

        first.setNote("  Elbows in \n", in: context)
        expect("note: saved on that workout's exercise, trimmed", first.note, "Elbows in")
        expect("note: not carried to another workout by default", later.note, nil)
        expect("note: not pinned by default", pinnedCount(), 0)

        first.pinNote(in: context)
        expect("pin: the note is found by name from a later workout", PinnedNote.find(named: later.name, in: context)?.text, "Elbows in")
        expect("pin: the row copy is cleared so the note shows once", first.note, nil)
        expect("pin: other exercises have none", PinnedNote.find(named: "Barbell Row", in: context)?.text, nil)

        later.setNote("Seat Level: 5", in: context)
        later.setNote("Seat Level: 5", in: context)
        expect("pin: editing a pinned note edits the pin", PinnedNote.find(named: "Bench Press", in: context)?.text, "Seat Level: 5")
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

        newer.setNote("  Left shoulder tight \n")
        expect("day note: trimmed on save", newer.note, "Left shoulder tight")
        newer.setNote("   ")
        expect("day note: blank stores nil", newer.note, nil)
    }
}

extension SetTarget: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(weight)
        hasher.combine(reps)
    }
}
