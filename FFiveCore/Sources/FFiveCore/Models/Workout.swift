import Foundation
import SwiftData

@Model
public final class Workout {
    public var name: String
    public internal(set) var startDate: Date
    public internal(set) var endDate: Date?
    @Relationship(deleteRule: .cascade, inverse: \Exercise.workout)
    public internal(set) var exercises: [Exercise] = []
    public internal(set) var mesocycle: Mesocycle?
    public internal(set) var week: Int?
    public internal(set) var dayIndex: Int?
    @Relationship(deleteRule: .cascade, inverse: \MuscleFeedbackRecord.workout)
    public var feedback: [MuscleFeedbackRecord] = []
    public internal(set) var note: String?

    public init(name: String, startDate: Date = .now) {
        self.name = name
        self.startDate = startDate
    }

    func setNote(_ text: String) {
        note = text.noteText
    }

    public var sortedExercises: [Exercise] { exercises.sorted { $0.order < $1.order } }
    public var duration: TimeInterval { (endDate ?? .now).timeIntervalSince(startDate) }
    public var completedSets: Int { exercises.reduce(0) { $0 + $1.sets.filter(\.isDone).count } }
    /// The share of planned sets logged, from 0 to 1.
    public var setProgress: Double {
        let total = exercises.reduce(0) { $0 + $1.sets.count }
        return total == 0 ? 0 : Double(completedSets) / Double(total)
    }
    public var isFullyLogged: Bool { !exercises.isEmpty && exercises.allSatisfy(\.isLogged) }
    public var totalVolume: Double {
        exercises.flatMap(\.sets).filter(\.isDone).reduce(0) { $0 + Double($1.reps) * $1.weight }
    }
    public var isFinished: Bool { endDate != nil }

    public var key: SessionKey? {
        guard let week, let dayIndex else { return nil }
        return SessionKey(week: week, dayIndex: dayIndex)
    }

    public var phase: WeekPhase? {
        guard let mesocycle, let week else { return nil }
        return mesocycle.phase(week: week)
    }

    /// Reps in reserve the logged sets were aimed at. Free-form sessions count as all-out,
    /// which keeps 1RM estimates conservative. Deload sets say nothing about strength.
    var effortRIR: Int? {
        guard let phase else { return 0 }
        return phase.rir
    }

    public var trainedMuscles: [Muscle] {
        var seen = Set<Muscle>()
        return sortedExercises.compactMap(\.muscle).filter { seen.insert($0).inserted }
    }

    public func exercises(for muscle: Muscle) -> [Exercise] {
        sortedExercises.filter { $0.muscle == muscle }
    }

    func setCount(for muscle: Muscle) -> Int {
        exercises(for: muscle).reduce(0) { $0 + $1.sets.count }
    }

    /// Whether any set for `muscle` was actually done, as opposed to only prescribed.
    func trained(_ muscle: Muscle) -> Bool {
        exercises(for: muscle).contains { $0.sets.contains(where: \.isDone) }
    }

    public func feedbackRecord(for muscle: Muscle) -> MuscleFeedbackRecord? {
        feedback.first { $0.muscleRaw == muscle.rawValue }
    }

    public func updateFeedback(for muscle: Muscle, _ change: (inout MuscleFeedback) -> Void) {
        let record = feedbackRecord(for: muscle) ?? {
            let record = MuscleFeedbackRecord(muscle: muscle)
            feedback.append(record)
            return record
        }()
        change(&record.value)
    }

    public func remove(_ exercise: Exercise, in context: ModelContext) {
        exercises.removeAll { $0 === exercise }
        context.delete(exercise)
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

extension Workout {
    public static var history: FetchDescriptor<Workout> {
        FetchDescriptor(predicate: #Predicate { $0.endDate != nil }, sortBy: [SortDescriptor(\.startDate, order: .reverse)])
    }

    public static var open: FetchDescriptor<Workout> {
        FetchDescriptor(predicate: #Predicate { $0.endDate == nil }, sortBy: [SortDescriptor(\.startDate, order: .reverse)])
    }
}
