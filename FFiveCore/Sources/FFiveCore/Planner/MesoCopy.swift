import Foundation

/// Starting a new block as a copy of a past or current one.
extension Mesocycle {
    /// A block's logged loads carry into its copy while its last accumulation session is younger than this.
    public static let carryWindow: TimeInterval = 21 * 24 * 60 * 60

    /// The weeks a copy can be taken from. The deload is left out, since a block never starts at deload effort.
    public var copyableWeeks: Range<Int> { 0..<accumulationWeeks }

    /// When the block's last accumulation session was finished, or nil when none was.
    public var lastAccumulationDate: Date? {
        workouts.filter { $0.phase?.rir != nil }.compactMap(\.endDate).max()
    }

    /// Whether a copy made at `now` starts from the loads logged in this block.
    public func carriesLoads(now: Date = .now) -> Bool {
        guard let last = lastAccumulationDate else { return false }
        return now.timeIntervalSince(last) < Self.carryWindow
    }

    /// A draft with this block's length, priorities, day names and weekdays, and the exercises `week` trained.
    /// A day whose session in that week was never built or was skipped takes the exercises its plan lists. When
    /// `carriesLoads(now:)` holds, each exercise starts from the sets logged on it that week: a logged set gives its
    /// weight and reps, a set left untouched repeats its target, and skipped sets and myoreps are dropped.
    public func copyDraft(week: Int, now: Date = .now) -> MesoDraft {
        let carry = carriesLoads(now: now)
        var draft = MesoDraft(template: nil)
        draft.name = name
        draft.accumulationWeeks = accumulationWeeks
        draft.priorities = Dictionary(uniqueKeysWithValues: muscles.map { ($0, priority(of: $0)) })
            .filter { $0.value != .normal }
        draft.days = sortedDays.enumerated().map { index, day in
            let session = workout(at: SessionKey(week: week, dayIndex: index))
            let slots: [MesoDraft.Slot] =
                if let session {
                    session.plannedExercises.compactMap { exercise in
                        exercise.muscle.map {
                            MesoDraft.Slot(
                                exercise: exercise.name, muscle: $0,
                                startingTargets: carry ? Self.startingTargets(from: exercise) : nil)
                        }
                    }
                } else {
                    day.sortedSlots.compactMap { slot in
                        slot.muscle.map { MesoDraft.Slot(exercise: slot.exerciseName, muscle: $0) }
                    }
                }
            return MesoDraft.Day(name: day.name, weekday: day.weekday, slots: slots)
        }
        return draft
    }

    private static func startingTargets(from exercise: Exercise) -> [SetTarget]? {
        let targets = exercise.sortedSets.compactMap { set -> SetTarget? in
            guard set.type.countsTowardProgression else { return nil }
            switch set.status {
            case .done: return SetTarget(weight: set.weight, reps: set.reps)
            case .pending: return set.target
            case .skipped: return nil
            }
        }
        return targets.contains { $0.weight != nil || $0.reps != nil } ? targets : nil
    }
}
