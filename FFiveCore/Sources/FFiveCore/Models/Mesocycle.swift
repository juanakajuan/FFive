import Foundation
import SwiftData

@Model
public final class Mesocycle {
    public internal(set) var name: String = ""
    public internal(set) var startDate: Date = Date.now
    public internal(set) var accumulationWeeks: Int = 4
    public internal(set) var finishedDate: Date?
    @Relationship(deleteRule: .cascade, originalName: "days", inverse: \MesoDay.mesocycle)
    var storedDays: [MesoDay]?
    @Relationship(deleteRule: .nullify, originalName: "workouts", inverse: \Workout.mesocycle)
    var storedWorkouts: [Workout]?
    var skippedSessions: [SessionKey] = []
    /// Muscle raw value to priority raw value. A muscle missing here is trained at normal priority.
    var musclePriorityRaw: [String: String] = [:]
    public internal(set) var notes: [MesoNote] = []

    public internal(set) var days: [MesoDay] {
        get { storedDays ?? [] }
        set { storedDays = newValue }
    }

    public internal(set) var workouts: [Workout] {
        get { storedWorkouts ?? [] }
        set { storedWorkouts = newValue }
    }

    init(name: String, accumulationWeeks: Int, startDate: Date = .now) {
        self.name = name
        self.accumulationWeeks = accumulationWeeks
        self.startDate = startDate
    }

    var sortedDays: [MesoDay] { days.sorted { $0.order < $1.order } }
    public var dayNames: [String] { sortedDays.map(\.name) }
    public var weekdays: [Weekday?] { sortedDays.map(\.weekday) }
    public var isActive: Bool { finishedDate == nil }

    /// Later weeks are built from the day's name, so renaming it also relabels the sessions already built.
    func renameDay(_ dayIndex: Int, to name: String) {
        let days = sortedDays
        guard days.indices.contains(dayIndex) else { return }
        days[dayIndex].name = name
        for workout in workouts where workout.dayIndex == dayIndex { workout.name = name }
    }

    /// Later weeks are built with the day's weekday, so relabeling it also relabels the sessions already built.
    func relabelDay(_ dayIndex: Int, as weekday: Weekday?) {
        let days = sortedDays
        guard days.indices.contains(dayIndex) else { return }
        days[dayIndex].weekday = weekday
        for workout in workouts where workout.dayIndex == dayIndex { workout.weekday = weekday }
    }

    public func priority(of muscle: Muscle) -> MusclePriority {
        musclePriorityRaw[muscle.rawValue].flatMap(MusclePriority.init(rawValue:)) ?? .normal
    }

    /// Takes effect from the next session built; sessions already built keep their sets.
    func setPriority(_ priority: MusclePriority, of muscle: Muscle) {
        musclePriorityRaw[muscle.rawValue] = priority == .normal ? nil : priority.rawValue
    }

    /// Every muscle a day of the block trains, in catalog order.
    public var muscles: [Muscle] {
        let trained = Set(days.flatMap(\.slots).compactMap(\.muscle))
        return Muscle.allCases.filter(trained.contains)
    }

    func addNote(_ text: String) {
        guard let note = MesoNote(text: text) else { return }
        notes.append(note)
    }

    func deleteNote(_ note: MesoNote) {
        notes.removeAll { $0.id == note.id }
    }

    public var totalWeeks: Int { accumulationWeeks + 1 }

    /// How many accumulation weeks a block can have, before and while it runs.
    public static let accumulationWeekRange = 3...6

    /// Adding a week turns the deload into an accumulation week, so the deload must not be logged.
    public var canAddWeek: Bool {
        isActive && accumulationWeeks < Self.accumulationWeekRange.upperBound && !isLogged(week: accumulationWeeks)
    }

    /// Removing a week drops the last accumulation week and moves the deload onto it, so neither may be logged.
    public var canRemoveWeek: Bool {
        isActive && accumulationWeeks > Self.accumulationWeekRange.lowerBound
            && !isLogged(week: accumulationWeeks - 1) && !isLogged(week: accumulationWeeks)
    }

    private func isLogged(week: Int) -> Bool {
        workouts.contains { $0.week == week && $0.hasLog }
    }

    /// Adds (`delta` 1) or removes (`delta` -1) an accumulation week, which moves the deload and every week's RIR.
    /// Logged sessions keep the RIR they were trained at. Unlogged sessions of a week the block lost are deleted, and
    /// so are skips of a week that became or stopped being the deload. Returns the unlogged sessions whose week
    /// changed, in plan order, for the caller to rebuild. A refused change returns nil and changes nothing.
    func changeLength(by delta: Int, in context: ModelContext) -> [Workout]? {
        guard delta == 1 ? canAddWeek : delta == -1 && canRemoveWeek else { return nil }
        let before = Dictionary(uniqueKeysWithValues: (0..<totalWeeks).map { ($0, phase(week: $0)) })
        for workout in workouts where workout.hasLog && workout.trainedRIR == nil {
            workout.trainedRIR = workout.week.flatMap { before[$0]?.rir }
        }
        accumulationWeeks += delta

        var rebuild: [Workout] = []
        for workout in workouts where !workout.hasLog {
            guard let week = workout.week else { continue }
            if week >= totalWeeks {
                workouts.removeAll { $0 === workout }
                context.delete(workout)
            } else if before[week] != phase(week: week) {
                rebuild.append(workout)
            }
        }
        skippedSessions.removeAll {
            $0.week >= totalWeeks || (before[$0.week] == .deload) != (phase(week: $0.week) == .deload)
        }
        return rebuild.sorted {
            ($0.key ?? SessionKey(week: 0, dayIndex: 0)) < ($1.key ?? SessionKey(week: 0, dayIndex: 0))
        }
    }

    public func phase(week: Int) -> WeekPhase {
        Progression.phase(week: week, accumulationWeeks: accumulationWeeks)
    }

    public var allKeys: [SessionKey] {
        (0..<totalWeeks).flatMap { week in days.indices.map { SessionKey(week: week, dayIndex: $0) } }
    }

    public func workout(at key: SessionKey) -> Workout? {
        workouts.first { $0.key == key }
    }

    /// The built, unfinished sessions of `key`'s day in later weeks.
    func laterOpenSessions(after key: SessionKey) -> [Workout] {
        workouts.filter { !$0.isFinished && $0.dayIndex == key.dayIndex && ($0.week ?? 0) > key.week }
    }

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

    /// The sessions with a logged set, which go with the block when it is deleted.
    public var loggedWorkoutCount: Int { workouts.filter(\.hasLog).count }

    /// Deletes the block with every session built for it, so its logged sets leave History and Progress.
    func delete(in context: ModelContext) {
        let built = workouts
        workouts = []
        built.forEach(context.delete)
        context.delete(self)
    }
}

extension Mesocycle {
    public static var active: FetchDescriptor<Mesocycle> {
        FetchDescriptor(
            predicate: #Predicate { $0.finishedDate == nil }, sortBy: [SortDescriptor(\.startDate, order: .reverse)])
    }
}
