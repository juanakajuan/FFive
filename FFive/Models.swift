import Foundation
import SwiftData

// Every stored property added after the first release is optional or defaulted, so SwiftData's
// lightweight migration opens stores written by earlier builds without losing history.

@Model
final class Workout {
    var name: String
    var startDate: Date
    var endDate: Date?
    @Relationship(deleteRule: .cascade, inverse: \Exercise.workout)
    var exercises: [Exercise] = []
    var mesocycle: Mesocycle?
    var week: Int?
    var dayIndex: Int?
    @Relationship(deleteRule: .cascade, inverse: \MuscleFeedbackRecord.workout)
    var feedback: [MuscleFeedbackRecord] = []
    var note: String?

    init(name: String, startDate: Date = .now) {
        self.name = name
        self.startDate = startDate
    }

    var sortedExercises: [Exercise] { exercises.sorted { $0.order < $1.order } }
    var duration: TimeInterval { (endDate ?? .now).timeIntervalSince(startDate) }
    var completedSets: Int { exercises.reduce(0) { $0 + $1.sets.filter(\.isDone).count } }
    /// The share of planned sets logged, from 0 to 1.
    var setProgress: Double {
        let total = exercises.reduce(0) { $0 + $1.sets.count }
        return total == 0 ? 0 : Double(completedSets) / Double(total)
    }
    var isFullyLogged: Bool { !exercises.isEmpty && exercises.allSatisfy(\.isLogged) }
    var totalVolume: Double {
        exercises.flatMap(\.sets).filter(\.isDone).reduce(0) { $0 + Double($1.reps) * $1.weight }
    }
    var isFinished: Bool { endDate != nil }

    func setNote(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        note = trimmed.isEmpty ? nil : trimmed
    }

    var key: SessionKey? {
        guard let week, let dayIndex else { return nil }
        return SessionKey(week: week, dayIndex: dayIndex)
    }

    var phase: WeekPhase? {
        guard let mesocycle, let week else { return nil }
        return mesocycle.phase(week: week)
    }

    /// Reps in reserve the logged sets were aimed at. Free-form sessions count as all-out,
    /// which keeps 1RM estimates conservative. Deload sets say nothing about strength.
    var effortRIR: Int? {
        guard let phase else { return 0 }
        return phase.rir
    }

    var trainedMuscles: [Muscle] {
        var seen = Set<Muscle>()
        return sortedExercises.compactMap(\.muscle).filter { seen.insert($0).inserted }
    }

    func exercises(for muscle: Muscle) -> [Exercise] {
        sortedExercises.filter { $0.muscle == muscle }
    }

    func setCount(for muscle: Muscle) -> Int {
        exercises(for: muscle).reduce(0) { $0 + $1.sets.count }
    }

    /// Whether any set for `muscle` was actually done, as opposed to only prescribed.
    func trained(_ muscle: Muscle) -> Bool {
        exercises(for: muscle).contains { $0.sets.contains(where: \.isDone) }
    }

    func feedbackRecord(for muscle: Muscle) -> MuscleFeedbackRecord? {
        feedback.first { $0.muscleRaw == muscle.rawValue }
    }

    func updateFeedback(for muscle: Muscle, _ change: (inout MuscleFeedback) -> Void) {
        let record = feedbackRecord(for: muscle) ?? {
            let record = MuscleFeedbackRecord(muscle: muscle)
            feedback.append(record)
            return record
        }()
        change(&record.value)
    }

    /// Free-form sessions drop what was never done. Mesocycle sessions keep the full prescription,
    /// because next week's plan is built from it and an untouched set means "repeat the target".
    func finish(in context: ModelContext) {
        if mesocycle == nil {
            for exercise in exercises {
                if !exercise.sets.contains(where: \.isDone) {
                    context.delete(exercise)
                } else {
                    for set in exercise.sets where !set.isDone { context.delete(set) }
                }
            }
        }
        endDate = .now
    }
}

@Model
final class Exercise {
    var name: String
    var order: Int
    var workout: Workout?
    @Relationship(deleteRule: .cascade, inverse: \SetEntry.exercise)
    var sets: [SetEntry] = []
    var muscleRaw: String?

    init(name: String, order: Int, muscle: Muscle? = nil) {
        self.name = name
        self.order = order
        self.muscleRaw = muscle?.rawValue
    }

    var sortedSets: [SetEntry] { sets.sorted { $0.order < $1.order } }
    var isLogged: Bool { !sets.isEmpty && sets.allSatisfy(\.isDone) }
    var info: ExerciseInfo? { ExerciseCatalog.info(named: name) }

    /// Rows logged before muscles were stored resolve through the catalog.
    var muscle: Muscle? {
        get { muscleRaw.flatMap(Muscle.init(rawValue:)) ?? info?.muscle }
        set { muscleRaw = newValue?.rawValue }
    }

    var repRange: ClosedRange<Int> { ExerciseCatalog.repRange(for: name) }

    func increment(_ unit: WeightUnit) -> Double {
        ExerciseCatalog.increment(for: name, unit: unit)
    }

    /// The done, loaded set with the highest estimated 1RM, or nil when no set says anything about strength.
    var strongestSet: (entry: SetEntry, oneRepMax: Double)? {
        guard let rir = workout?.effortRIR else { return nil }
        return sets.filter { $0.isDone && $0.weight > 0 && $0.reps > 0 }
            .map { ($0, Progression.estimatedOneRepMax(weight: $0.weight, reps: $0.reps, rir: rir)) }
            .max { $0.1 < $1.1 }
    }
}

@Model
final class ExerciseNote {
    var name: String = ""
    var text: String = ""

    init(name: String, text: String) {
        self.name = name
        self.text = text
    }

    private static func all(named name: String, in context: ModelContext) -> [ExerciseNote] {
        (try? context.fetch(FetchDescriptor<ExerciseNote>(predicate: #Predicate { $0.name == name }))) ?? []
    }

    static func find(named name: String, in context: ModelContext) -> ExerciseNote? {
        all(named: name, in: context).first
    }

    static func delete(for name: String, in context: ModelContext) {
        all(named: name, in: context).forEach(context.delete)
    }

    static func set(_ text: String, for name: String, in context: ModelContext) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return delete(for: name, in: context) }
        let existing = all(named: name, in: context)
        if let first = existing.first {
            first.text = trimmed
            existing.dropFirst().forEach(context.delete)
        } else {
            context.insert(ExerciseNote(name: name, text: trimmed))
        }
    }
}

@Model
final class SetEntry {
    var reps: Int
    var weight: Double
    var isDone: Bool = false
    var order: Int
    var exercise: Exercise?
    var targetWeight: Double?
    var targetReps: Int?

    init(reps: Int, weight: Double, order: Int) {
        self.reps = reps
        self.weight = weight
        self.order = order
    }

    /// A prescribed set, prefilled with its target so checking it off logs the target.
    convenience init(target: SetTarget, order: Int) {
        self.init(reps: target.reps ?? 0, weight: target.weight ?? 0, order: order)
        targetWeight = target.weight
        targetReps = target.reps
    }

    var target: SetTarget { SetTarget(weight: targetWeight, reps: targetReps) }
    var logged: LoggedSet? { isDone ? LoggedSet(weight: weight, reps: reps) : nil }
}

@Model
final class Mesocycle {
    var name: String = ""
    var startDate: Date = Date.now
    var accumulationWeeks: Int = 4
    var finishedDate: Date?
    @Relationship(deleteRule: .cascade, inverse: \MesoDay.mesocycle)
    var days: [MesoDay] = []
    @Relationship(deleteRule: .nullify, inverse: \Workout.mesocycle)
    var workouts: [Workout] = []
    var skippedSessions: [SessionKey] = []

    init(name: String, accumulationWeeks: Int, startDate: Date = .now) {
        self.name = name
        self.accumulationWeeks = accumulationWeeks
        self.startDate = startDate
    }

    var sortedDays: [MesoDay] { days.sorted { $0.order < $1.order } }
    /// Accumulation weeks plus the deload.
    var totalWeeks: Int { accumulationWeeks + 1 }

    func phase(week: Int) -> WeekPhase {
        Progression.phase(week: week, accumulationWeeks: accumulationWeeks)
    }

    var allKeys: [SessionKey] {
        (0..<totalWeeks).flatMap { week in days.indices.map { SessionKey(week: week, dayIndex: $0) } }
    }

    func workout(at key: SessionKey) -> Workout? {
        workouts.first { $0.key == key }
    }

    /// The session after which this one is planned: the latest earlier week on the same day.
    func latestWorkout(dayIndex: Int, before week: Int) -> Workout? {
        workouts
            .filter { $0.dayIndex == dayIndex && ($0.week ?? .max) < week }
            .max { ($0.week ?? 0) < ($1.week ?? 0) }
    }

    func status(at key: SessionKey) -> SessionStatus {
        if let workout = workout(at: key) {
            return workout.isFinished ? .finished(workout) : .inProgress(workout)
        }
        return skippedSessions.contains(key) ? .skipped : .upcoming
    }

    /// The first session in plan order still to train, or nil when every session is done or skipped.
    var nextUp: SessionKey? {
        allKeys.first { status(at: $0).isOpen }
    }

    func canSkip(_ key: SessionKey) -> Bool {
        switch status(at: key) {
        case .upcoming, .skipped: true
        case .inProgress(let workout): workout.completedSets == 0
        case .finished: false
        }
    }

    /// Drops an untouched session from the block so the plan moves on. Next week's same day builds from
    /// the last session actually trained, so a skipped day has no workout row.
    func skip(_ key: SessionKey, in context: ModelContext) {
        guard canSkip(key) else { return }
        if case .inProgress(let workout) = status(at: key) {
            workouts.removeAll { $0 === workout }
            context.delete(workout)
        }
        if !skippedSessions.contains(key) { skippedSessions.append(key) }
    }

    func unskip(_ key: SessionKey) {
        skippedSessions.removeAll { $0 == key }
    }

    /// Ends the block. Open sessions with logged sets are finished so they reach history; untouched ones,
    /// such as a day built only because it was shown, are dropped.
    func end(in context: ModelContext) {
        for workout in workouts where !workout.isFinished {
            if workout.completedSets > 0 {
                workout.finish(in: context)
            } else {
                workouts.removeAll { $0 === workout }
                context.delete(workout)
            }
        }
        finishedDate = .now
    }
}

enum SessionStatus: Equatable {
    case upcoming
    case inProgress(Workout)
    case finished(Workout)
    case skipped

    var isOpen: Bool {
        switch self {
        case .upcoming, .inProgress: true
        case .finished, .skipped: false
        }
    }
}

@Model
final class MesoDay {
    var name: String = ""
    var order: Int = 0
    var mesocycle: Mesocycle?
    @Relationship(deleteRule: .cascade, inverse: \DaySlot.day)
    var slots: [DaySlot] = []

    init(name: String, order: Int) {
        self.name = name
        self.order = order
    }

    var sortedSlots: [DaySlot] { slots.sorted { $0.order < $1.order } }
}

@Model
final class DaySlot {
    var exerciseName: String = ""
    var muscleRaw: String = ""
    var order: Int = 0
    var day: MesoDay?

    init(exerciseName: String, muscle: Muscle, order: Int) {
        self.exerciseName = exerciseName
        self.muscleRaw = muscle.rawValue
        self.order = order
    }

    var muscle: Muscle? { Muscle(rawValue: muscleRaw) }
}

@Model
final class MuscleFeedbackRecord {
    var muscleRaw: String = ""
    var sorenessRaw: Int?
    var pumpRaw: Int?
    var workloadRaw: Int?
    var jointPainRaw: Int?
    var workout: Workout?

    init(muscle: Muscle) {
        self.muscleRaw = muscle.rawValue
    }

    var muscle: Muscle? { Muscle(rawValue: muscleRaw) }

    var value: MuscleFeedback {
        get {
            MuscleFeedback(soreness: sorenessRaw.flatMap(Soreness.init(rawValue:)),
                           pump: pumpRaw.flatMap(Pump.init(rawValue:)),
                           workload: workloadRaw.flatMap(Workload.init(rawValue:)),
                           jointPain: jointPainRaw.flatMap(JointPain.init(rawValue:)))
        }
        set {
            sorenessRaw = newValue.soreness?.rawValue
            pumpRaw = newValue.pump?.rawValue
            workloadRaw = newValue.workload?.rawValue
            jointPainRaw = newValue.jointPain?.rawValue
        }
    }
}

struct SessionKey: Hashable, Comparable, Codable {
    let week: Int
    let dayIndex: Int

    static func < (lhs: SessionKey, rhs: SessionKey) -> Bool {
        (lhs.week, lhs.dayIndex) < (rhs.week, rhs.dayIndex)
    }
}

enum AppStore {
    static let schema = Schema([
        Workout.self, Exercise.self, SetEntry.self,
        Mesocycle.self, MesoDay.self, DaySlot.self, MuscleFeedbackRecord.self,
        ExerciseNote.self,
    ])

    static func makeContainer(inMemory: Bool) -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            fatalError("Could not open the workout store: \(error)")
        }
    }
}

func formatDuration(_ interval: TimeInterval) -> String {
    let minutes = max(0, Int(interval) / 60)
    return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
}

func formatWeight(_ weight: Double) -> String {
    weight.formatted(.number.precision(.fractionLength(0...1)))
}
