import Foundation
import SwiftData

/// A program layout the lifter saved from a mesocycle or a builder draft.
@Model
public final class CustomTemplate {
    public internal(set) var name: String = ""
    public internal(set) var createdDate: Date = Date.now
    /// JSON of `[Layout.Day]`. Kept as bytes so SwiftData stores the nested day and slot arrays as one value.
    private var layoutData = Data()

    struct Layout {
        struct Day: Codable, Hashable {
            var name: String
            var slots: [Slot]
        }

        struct Slot: Codable, Hashable {
            var exercise: String
            var muscle: Muscle
        }
    }

    init(name: String, days: [Layout.Day]) {
        self.name = name
        self.days = days
    }

    var days: [Layout.Day] {
        get { (try? JSONDecoder().decode([Layout.Day].self, from: layoutData)) ?? [] }
        set { layoutData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    public var template: ProgramTemplate {
        let days = days.map { day in
            TemplateDay(
                name: day.name, exerciseNames: day.slots.map(\.exercise),
                slots: day.slots.map { TemplateSlot(muscle: $0.muscle, exercise: $0.exercise) })
        }
        return ProgramTemplate(name: name, emphasis: nil, summary: days.map(\.name).joined(separator: ", "), days: days)
    }
}

extension CustomTemplate {
    public static var all: FetchDescriptor<CustomTemplate> {
        FetchDescriptor(sortBy: [SortDescriptor(\.name)])
    }

    static func referencing(_ key: ExerciseID, in context: ModelContext) -> [CustomTemplate] {
        ((try? context.fetch(all)) ?? []).filter { template in
            template.days.contains { $0.slots.contains { ExerciseID(folding: $0.exercise) == key } }
        }
    }

    static func layout(of draft: MesoDraft) -> [Layout.Day] {
        draft.days.filter { !$0.slots.isEmpty }.map { day in
            Layout.Day(name: day.name, slots: day.slots.map { Layout.Slot(exercise: $0.exercise, muscle: $0.muscle) })
        }
    }

    static func layout(of meso: Mesocycle) -> [Layout.Day] {
        meso.sortedDays.map { day in
            Layout.Day(
                name: day.name,
                slots: day.sortedSlots.compactMap { slot in
                    slot.muscle.map { Layout.Slot(exercise: slot.exerciseName, muscle: $0) }
                })
        }
        .filter { !$0.slots.isEmpty }
    }
}
