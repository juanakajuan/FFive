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

    /// The on-device store mirrors to the iCloud container named in the app's entitlements. CloudKit requires every
    /// attribute to be optional or defaulted and every relationship optional, which `CloudKitSchemaTests` checks.
    public static func makeContainer(inMemory: Bool) -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema, isStoredInMemoryOnly: inMemory, cloudKitDatabase: inMemory ? .none : .automatic)
        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            fatalError("Could not open the workout store: \(error)")
        }
    }
}
