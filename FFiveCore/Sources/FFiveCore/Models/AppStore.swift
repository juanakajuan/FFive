import Foundation
import SwiftData

// Every stored property added after the first release is optional or defaulted, so SwiftData's
// lightweight migration opens stores written by earlier builds without losing history.
public enum AppStore {
    static let schema = Schema([
        Workout.self, Exercise.self, SetEntry.self,
        Mesocycle.self, MesoDay.self, DaySlot.self, MuscleFeedbackRecord.self,
        PinnedNote.self, CustomTemplate.self, CustomExercise.self,
    ])

    public static func makeContainer(inMemory: Bool) -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            fatalError("Could not open the workout store: \(error)")
        }
    }
}
