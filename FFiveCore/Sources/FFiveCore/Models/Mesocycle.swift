import Foundation
import SwiftData

@Model
public final class Mesocycle {
    public var name: String = ""
    public internal(set) var startDate: Date = Date.now
    public var accumulationWeeks: Int = 4
    public internal(set) var finishedDate: Date?
    @Relationship(deleteRule: .cascade, inverse: \MesoDay.mesocycle)
    public internal(set) var days: [MesoDay] = []
    @Relationship(deleteRule: .nullify, inverse: \Workout.mesocycle)
    public internal(set) var workouts: [Workout] = []
    var skippedSessions: [SessionKey] = []

    init(name: String, accumulationWeeks: Int, startDate: Date = .now) {
        self.name = name
        self.accumulationWeeks = accumulationWeeks
        self.startDate = startDate
    }

    var sortedDays: [MesoDay] { days.sorted { $0.order < $1.order } }
    /// Accumulation weeks plus the deload.
    public var totalWeeks: Int { accumulationWeeks + 1 }

    public func phase(week: Int) -> WeekPhase {
        Progression.phase(week: week, accumulationWeeks: accumulationWeeks)
    }

    public var allKeys: [SessionKey] {
        (0..<totalWeeks).flatMap { week in days.indices.map { SessionKey(week: week, dayIndex: $0) } }
    }

    public func workout(at key: SessionKey) -> Workout? {
        workouts.first { $0.key == key }
    }

    /// The session after which this one is planned: the latest earlier week on the same day.
    func latestWorkout(dayIndex: Int, before week: Int) -> Workout? {
        workouts
            .filter { $0.dayIndex == dayIndex && ($0.week ?? .max) < week }
            .max { ($0.week ?? 0) < ($1.week ?? 0) }
    }

    public func status(at key: SessionKey) -> SessionStatus {
        if let workout = workout(at: key) {
            return workout.isFinished ? .finished(workout) : .inProgress(workout)
        }
        return skippedSessions.contains(key) ? .skipped : .upcoming
    }

    /// The first session in plan order still to train, or nil when every session is done or skipped.
    public var nextUp: SessionKey? {
        allKeys.first { status(at: $0).isOpen }
    }

    public func canSkip(_ key: SessionKey) -> Bool {
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

extension Mesocycle {
    public static var active: FetchDescriptor<Mesocycle> {
        FetchDescriptor(
            predicate: #Predicate { $0.finishedDate == nil }, sortBy: [SortDescriptor(\.startDate, order: .reverse)])
    }
}
