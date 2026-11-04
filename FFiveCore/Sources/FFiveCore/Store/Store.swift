import Foundation
import Observation
import SwiftData

public enum StoreError: Error, Equatable {
    case anotherMesocycleIsActive
}

/// The one writer of block and workout lifecycle. Views read the models and ask the store to change them.
@MainActor
@Observable
public final class Store {
    public let container: ModelContainer
    let context: ModelContext
    public private(set) var revision = 0
    /// The error of the last commit that did not save, until a screen has shown it.
    public private(set) var failure: (any Error)?

    public init(inMemory: Bool) {
        container = AppStore.makeContainer(inMemory: inMemory)
        context = container.mainContext
    }

    public func startMesocycle(_ draft: MesoDraft) throws {
        guard try context.fetchCount(Mesocycle.active) == 0 else { throw StoreError.anotherMesocycleIsActive }
        MesoPlanner.start(draft, in: context)
        commit()
    }

    public func endMesocycle(_ meso: Mesocycle) {
        meso.end(in: context)
        commit()
    }

    public func skip(_ key: SessionKey, of meso: Mesocycle) {
        meso.skip(key, in: context)
        commit()
    }

    public func unskip(_ key: SessionKey, of meso: Mesocycle) {
        meso.unskip(key)
        commit()
    }

    @discardableResult
    public func buildSession(_ meso: Mesocycle, at key: SessionKey, unit: WeightUnit) -> Workout {
        let workout = MesoPlanner.workout(for: meso, at: key, unit: unit, in: context)
        commit()
        return workout
    }

    /// A block day is built as soon as the tab shows it. Until a set is logged its clock restarts each time it is
    /// shown, so duration and the soreness lookback count from when training began.
    public func show(_ workout: Workout) {
        guard workout.mesocycle != nil, workout.completedSets == 0 else { return }
        workout.startDate = .now
        commit()
    }

    public func finish(_ workout: Workout) {
        workout.finish(in: context)
        commit()
    }

    public func delete(_ workout: Workout) {
        workout.mesocycle?.workouts.removeAll { $0 === workout }
        context.delete(workout)
        commit()
    }

    @discardableResult
    public func startQuickWorkout() -> Workout {
        let workout = Workout(name: Self.defaultWorkoutName())
        context.insert(workout)
        commit()
        return workout
    }

    public func dismissFailure() {
        failure = nil
    }

    func commit() {
        do {
            try context.save()
            revision += 1
        } catch {
            failure = error
        }
    }

    private static func defaultWorkoutName() -> String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: "Morning Workout"
        case 12..<17: "Afternoon Workout"
        default: "Evening Workout"
        }
    }
}
