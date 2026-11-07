import Foundation
import SwiftData

/// Everything the lifter has logged or built, as plain values for a JSON file they keep outside the app.
struct TrainingExport: Codable, Equatable {
    var format = "ffive-training-export"
    var version = 1
    var exportedAt: Date
    var weightUnit: String
    var mesocycles: [Meso]
    /// Sessions started outside any mesocycle.
    var workouts: [Session]
    var customExercises: [CustomExerciseValue]
    /// Catalog exercises the lifter hid from pickers, by folded name.
    var hiddenExercises: [String]
    var templates: [Template]
    var pinnedNotes: [PinnedNoteValue]

    struct Meso: Codable, Equatable {
        var name: String
        var startDate: Date
        var finishedDate: Date?
        var accumulationWeeks: Int
        var days: [Day]
        var musclePriorities: [String: String]
        var skippedSessions: [SessionKey]
        var workouts: [Session]
    }

    struct Day: Codable, Equatable {
        var name: String
        var weekday: String?
        var slots: [Slot]
    }

    struct Slot: Codable, Equatable {
        var exercise: String
        var muscle: String
    }

    struct Session: Codable, Equatable {
        var name: String
        var startDate: Date
        var endDate: Date?
        var week: Int?
        var dayIndex: Int?
        var weekday: String?
        var bodyweight: Double?
        var note: String?
        var exercises: [ExerciseValue]
        var feedback: [Feedback]
    }

    struct ExerciseValue: Codable, Equatable {
        var name: String
        var muscle: String?
        var note: String?
        var sets: [SetValue]
    }

    struct SetValue: Codable, Equatable {
        var status: String
        var type: String
        var weight: Double
        var reps: Int
        var targetWeight: Double?
        var targetReps: Int?
    }

    struct Feedback: Codable, Equatable {
        var muscle: String
        var soreness: String?
        var pump: String?
        var workload: String?
        var jointPain: String?
    }

    struct CustomExerciseValue: Codable, Equatable {
        var name: String
        var muscle: String
        var equipment: String
        var minReps: Int
        var maxReps: Int
        var cue: String?
        var isHidden: Bool
    }

    struct Template: Codable, Equatable {
        var name: String
        var createdDate: Date
        var days: [Day]
    }

    struct PinnedNoteValue: Codable, Equatable {
        var exercise: String
        var text: String
    }

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}

extension TrainingExport {
    @MainActor init(context: ModelContext, settings: Settings, now: Date) throws {
        let mesos = try context.fetch(FetchDescriptor<Mesocycle>(sortBy: [SortDescriptor(\.startDate)]))
        let workouts = try context.fetch(FetchDescriptor<Workout>(sortBy: [SortDescriptor(\.startDate)]))
        let templates = try context.fetch(FetchDescriptor<CustomTemplate>(sortBy: [SortDescriptor(\.createdDate)]))
        let notes = try context.fetch(FetchDescriptor<PinnedNote>(sortBy: [SortDescriptor(\.name)]))
        let custom = try context.fetch(FetchDescriptor<CustomExercise>(sortBy: [SortDescriptor(\.name)]))
        self.init(
            exportedAt: now,
            weightUnit: settings.weightUnit.rawValue,
            mesocycles: mesos.map(Meso.init),
            workouts: workouts.filter { $0.mesocycle == nil }.map(Session.init),
            customExercises: custom.map {
                CustomExerciseValue(
                    name: $0.name, muscle: $0.muscle.rawValue, equipment: $0.equipment.rawValue,
                    minReps: $0.repRange.lowerBound, maxReps: $0.repRange.upperBound, cue: $0.cue,
                    isHidden: $0.isHidden)
            },
            hiddenExercises: settings.hiddenExercises.map(\.rawValue).sorted(),
            templates: templates.map {
                Template(name: $0.name, createdDate: $0.createdDate, days: $0.days.map(Day.init))
            },
            pinnedNotes: notes.map { PinnedNoteValue(exercise: $0.name, text: $0.text) })
    }
}

extension TrainingExport.Meso {
    init(_ meso: Mesocycle) {
        self.init(
            name: meso.name,
            startDate: meso.startDate,
            finishedDate: meso.finishedDate,
            accumulationWeeks: meso.accumulationWeeks,
            days: meso.sortedDays.map { day in
                TrainingExport.Day(
                    name: day.name,
                    weekday: day.weekdayRaw,
                    slots: day.sortedSlots.map { TrainingExport.Slot(exercise: $0.exerciseName, muscle: $0.muscleRaw) })
            },
            musclePriorities: meso.musclePriorityRaw,
            skippedSessions: meso.skippedSessions.sorted(),
            workouts: meso.workouts.sorted { $0.startDate < $1.startDate }.map(TrainingExport.Session.init))
    }
}

extension TrainingExport.Day {
    init(_ day: CustomTemplate.Layout.Day) {
        self.init(
            name: day.name,
            slots: day.slots.map { TrainingExport.Slot(exercise: $0.exercise, muscle: $0.muscle.rawValue) })
    }
}

extension TrainingExport.Session {
    init(_ workout: Workout) {
        self.init(
            name: workout.name,
            startDate: workout.startDate,
            endDate: workout.endDate,
            week: workout.week,
            dayIndex: workout.dayIndex,
            weekday: workout.weekdayRaw,
            bodyweight: workout.bodyweight,
            note: workout.note,
            exercises: workout.sortedExercises.map { exercise in
                TrainingExport.ExerciseValue(
                    name: exercise.name,
                    muscle: exercise.muscle?.rawValue,
                    note: exercise.note,
                    sets: exercise.sortedSets.map(TrainingExport.SetValue.init))
            },
            feedback: workout.feedback.sorted { $0.muscleRaw < $1.muscleRaw }.map { record in
                let value = record.value
                return TrainingExport.Feedback(
                    muscle: record.muscleRaw,
                    soreness: value.soreness.map { "\($0)" },
                    pump: value.pump.map { "\($0)" },
                    workload: value.workload.map { "\($0)" },
                    jointPain: value.jointPain.map { "\($0)" })
            })
    }
}

extension TrainingExport.SetValue {
    init(_ set: SetEntry) {
        self.init(
            status: "\(set.status)", type: set.type.rawValue, weight: set.weight, reps: set.reps,
            targetWeight: set.targetWeight, targetReps: set.targetReps)
    }
}

extension Store {
    /// Every mesocycle, workout, set, feedback entry, custom exercise, saved template and pinned note, as JSON.
    public func exportJSON(now: Date = .now) throws -> Data {
        let export = try TrainingExport(context: context, settings: settings, now: now)
        return try TrainingExport.encoder.encode(export)
    }
}
