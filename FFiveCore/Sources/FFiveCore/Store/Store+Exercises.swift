import Foundation
import SwiftData

public enum CustomExerciseRemoval: Equatable {
    case deleted
    /// History or a plan still uses the exercise, so it is hidden instead of removed.
    case archived
}

extension Store {
    /// The catalog and custom exercises that match every filter, by name. `performedOnly` keeps only
    /// exercises with a logged set in a finished workout.
    public func library(
        muscle: Muscle?, equipment: Equipment?, search: String, includeHidden: Bool = false,
        performedOnly: Bool = false
    ) -> [ExerciseListing] {
        observeCommits()
        let hidden = settings.hiddenExercises
        let performed = performedOnly ? Set(ExerciseHistoryGroup.lastPerformed(in: context).keys) : []
        var listings = ExerciseCatalog.all.map {
            ExerciseListing(
                id: $0.id, name: $0.name, muscle: $0.muscle, info: $0, isCustom: false, isHidden: hidden.contains($0.id)
            )
        }
        listings += CustomExercise.all(in: context).map(Self.listing)
        let query = search.trimmingCharacters(in: .whitespaces)
        return
            listings
            .filter { includeHidden || !$0.isHidden }
            .filter { !performedOnly || performed.contains($0.id) }
            .filter { muscle == nil || $0.muscle == muscle }
            .filter { equipment == nil || $0.info.equipment == equipment }
            .filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
            .sorted {
                switch $0.name.localizedCaseInsensitiveCompare($1.name) {
                case .orderedSame: $0.id.rawValue < $1.id.rawValue
                case let order: order == .orderedAscending
                }
            }
    }

    private static func listing(_ custom: CustomExercise) -> ExerciseListing {
        ExerciseListing(
            id: custom.key, name: custom.name, muscle: custom.muscle, info: custom.info, isCustom: true,
            isHidden: custom.isHidden)
    }

    /// The current state of one exercise, hidden or not.
    public func listing(_ id: ExerciseID) -> ExerciseListing? {
        observeCommits()
        if let custom = CustomExercise.find(id, in: context) { return Self.listing(custom) }
        return ExerciseCatalog.info(id).map {
            ExerciseListing(
                id: id, name: $0.name, muscle: $0.muscle, info: $0, isCustom: false,
                isHidden: settings.hiddenExercises.contains(id))
        }
    }

    public func customExercise(_ id: ExerciseID) -> CustomExercise? {
        observeCommits()
        return CustomExercise.find(id, in: context)
    }

    /// Creates the exercise, or with `editing` rewrites it. A new name moves every reference to the new identity.
    public func saveCustomExercise(_ draft: CustomExerciseDraft, editing: CustomExercise? = nil) throws {
        guard let name = draft.name.noteText else { throw StoreError.nameEmpty }
        let key = ExerciseID(folding: name)
        let existing = CustomExercise.find(key, in: context)
        guard ExerciseCatalog.info(key) == nil, existing == nil || existing === editing else {
            throw StoreError.nameTaken
        }
        let lower = max(1, draft.repRange.lowerBound)
        var clean = draft
        clean.name = name
        clean.cue = draft.cue?.noteText
        clean.repRange = lower...max(lower, draft.repRange.upperBound)
        if let editing {
            cascade(from: editing, to: clean)
            editing.apply(clean)
        } else {
            let created = CustomExercise(name: name, muscle: clean.muscle)
            created.apply(clean)
            context.insert(created)
        }
        commit()
    }

    @discardableResult
    public func deleteCustomExercise(_ exercise: CustomExercise) -> CustomExerciseRemoval {
        let key = exercise.exerciseKey
        let logged =
            (try? context.fetchCount(FetchDescriptor<Exercise>(predicate: #Predicate { $0.exerciseKey == key }))) ?? 0
        let planned =
            (try? context.fetchCount(FetchDescriptor<DaySlot>(predicate: #Predicate { $0.exerciseKey == key }))) ?? 0
        let saved = CustomTemplate.referencing(exercise.key, in: context)
        let removal: CustomExerciseRemoval = logged + planned > 0 || !saved.isEmpty ? .archived : .deleted
        switch removal {
        case .archived:
            exercise.isHidden = true
        case .deleted:
            PinnedNote.delete(for: exercise.name, in: context)
            context.delete(exercise)
        }
        commit()
        return removal
    }

    public func isHidden(_ id: ExerciseID) -> Bool {
        observeCommits()
        if let custom = CustomExercise.find(id, in: context) { return custom.isHidden }
        return settings.hiddenExercises.contains(id)
    }

    public func setHidden(_ id: ExerciseID, _ hidden: Bool) {
        if let custom = CustomExercise.find(id, in: context) {
            custom.isHidden = hidden
        } else if ExerciseCatalog.info(id) != nil {
            if hidden { settings.hiddenExercises.insert(id) } else { settings.hiddenExercises.remove(id) }
        } else {
            return
        }
        commit()
    }

    private func cascade(from old: CustomExercise, to draft: CustomExerciseDraft) {
        let oldKey = old.exerciseKey
        let rows =
            (try? context.fetch(FetchDescriptor<Exercise>(predicate: #Predicate { $0.exerciseKey == oldKey }))) ?? []
        let slots =
            (try? context.fetch(FetchDescriptor<DaySlot>(predicate: #Predicate { $0.exerciseKey == oldKey }))) ?? []
        let newKey = ExerciseID(folding: draft.name)
        for name in Set(rows.map(\.name) + [old.name]) where name != draft.name {
            PinnedNote.rename(from: name, to: draft.name, in: context)
        }
        for row in rows {
            row.rename(draft.name)
            row.muscle = draft.muscle
        }
        for slot in slots {
            slot.exerciseName = draft.name
            slot.exerciseKey = newKey.rawValue
            slot.muscleRaw = draft.muscle.rawValue
        }
        for template in CustomTemplate.referencing(old.key, in: context) {
            template.days = template.days.map { day in
                var day = day
                day.slots = day.slots.map { slot in
                    guard ExerciseID(folding: slot.exercise) == old.key else { return slot }
                    return .init(exercise: draft.name, muscle: draft.muscle)
                }
                return day
            }
        }
    }

    /// Gives every non-catalog exercise that logs, slots or saved templates already use a record, with the defaults
    /// they were always planned with. Repeating it adds nothing.
    @discardableResult
    func backfillCustomExercises() -> Int {
        var known = Set(CustomExercise.all(in: context).map(\.key))
        var created = 0
        func record(_ name: String, _ muscle: Muscle?) {
            let key = ExerciseID(folding: name)
            guard let muscle, ExerciseCatalog.info(key) == nil, known.insert(key).inserted else { return }
            context.insert(CustomExercise(name: name, muscle: muscle))
            created += 1
        }
        for exercise in (try? context.fetch(FetchDescriptor<Exercise>())) ?? [] {
            record(exercise.name, exercise.muscleRaw.flatMap(Muscle.init(rawValue:)))
        }
        for slot in (try? context.fetch(FetchDescriptor<DaySlot>())) ?? [] {
            record(slot.exerciseName, slot.muscle)
        }
        for template in (try? context.fetch(CustomTemplate.all)) ?? [] {
            for slot in template.days.flatMap(\.slots) { record(slot.exercise, slot.muscle) }
        }
        if created > 0 { commit() }
        return created
    }
}
