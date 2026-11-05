import Foundation
import SwiftData

/// Seeds two free-form sessions, then a 4-week block on the first template with week 1 fully logged,
/// week 2 day 1 under way, and week 2's last day skipped. Everything runs through the planner so the demo
/// shows real prescriptions.
@MainActor
public enum DemoSeed {
    private static let day: TimeInterval = 86_400

    public static func seed(into store: Store) {
        let context = store.context
        let unit = store.settings.weightUnit
        let now = Date.now
        func snapshot() -> PlanningSnapshot { PlanningSnapshot(context: context) }

        quickWorkout(
            "Morning Workout", at: now - 19 * day,
            [
                ("Bench Press", .chest, [(155, 8), (155, 7), (155, 6)]),
                ("Squat", .quads, [(205, 6), (205, 6)]),
                ("Lateral Raise", .sideDelts, [(20, 14), (20, 12)]),
            ], unit: unit, context: context)
        quickWorkout(
            "Evening Workout", at: now - 16 * day,
            [
                ("Bench Press", .chest, [(160, 7), (160, 6)]),
                ("Romanian Deadlift", .hamstrings, [(185, 8), (185, 8)]),
                ("Lat Pulldown", .back, [(130, 11), (130, 10)]),
            ], unit: unit, context: context)

        guard let template = ExerciseCatalog.templates.first else {
            store.commit()
            return
        }
        let meso = MesoPlanner.start(MesoDraft(template: template), in: context)
        meso.startDate = now - 8 * day

        let sorenessAnswers: [Soreness] = [.healedEarly, .healedOnTime, .never, .healedOnTime]
        let feelings: [(Pump, Workload, JointPain)] = [
            (.moderate, .good, .none), (.great, .easy, .none), (.low, .good, .low),
            (.moderate, .hard, .none), (.great, .good, .none),
        ]
        var answer = 0
        for dayIndex in meso.days.indices {
            let start = meso.startDate + Double(dayIndex) * 2 * day
            let workout = MesoPlanner.workout(
                for: meso, at: SessionKey(week: 0, dayIndex: dayIndex), unit: unit,
                snapshot: snapshot(), in: context)
            workout.startDate = start
            let pending = workout.pendingSoreness
            for muscle in workout.trainedMuscles {
                guard let record = pending[muscle] else { continue }
                MesoPlanner.recordSoreness(
                    sorenessAnswers[answer % sorenessAnswers.count], on: record, during: workout,
                    unit: unit, snapshot: snapshot(), in: context)
                answer += 1
            }
            for (index, exercise) in workout.sortedExercises.enumerated() {
                logAllSets(of: exercise, beatTargetBy: (index + dayIndex) % 2, unit: unit)
            }
            for muscle in workout.trainedMuscles {
                let (pump, workload, pain) = feelings[answer % feelings.count]
                answer += 1
                workout.updateFeedback(for: muscle) {
                    $0.pump = pump
                    $0.workload = workload
                    $0.jointPain = pain
                }
            }
            workout.endDate = start + 64 * 60
        }

        let current = MesoPlanner.workout(
            for: meso, at: SessionKey(week: 1, dayIndex: 0), unit: unit,
            snapshot: snapshot(), in: context)
        current.startDate = now - 24 * 60
        if let first = current.trainedMuscles.first {
            if let record = current.pendingSoreness[first] {
                MesoPlanner.recordSoreness(
                    .healedOnTime, on: record, during: current, unit: unit, snapshot: snapshot(), in: context)
            }
            for exercise in current.exercises(for: first) {
                logAllSets(of: exercise, beatTargetBy: 0, unit: unit)
            }
        }
        if let lastDay = meso.days.indices.last, lastDay > 0 {
            meso.skip(SessionKey(week: 1, dayIndex: lastDay), in: context)
        }
        store.commit()
    }

    private static func quickWorkout(
        _ name: String, at start: Date, _ exercises: [(String, Muscle, [(Double, Int)])],
        unit: WeightUnit, context: ModelContext
    ) {
        let workout = Workout(name: name, startDate: start)
        context.insert(workout)
        for (order, (exerciseName, muscle, sets)) in exercises.enumerated() {
            let exercise = Exercise(name: exerciseName, order: order, muscle: muscle)
            workout.exercises.append(exercise)
            for (index, (weight, reps)) in sets.enumerated() {
                let set = SetEntry(reps: reps, weight: converted(weight, unit), order: index)
                set.isDone = true
                exercise.sets.append(set)
            }
        }
        workout.endDate = start + 50 * 60
    }

    /// Logs every set at its target, or at a plausible first-week load when the target says calibrate.
    private static func logAllSets(of exercise: Exercise, beatTargetBy extra: Int, unit: WeightUnit) {
        for set in exercise.sets {
            if let weight = set.targetWeight, let reps = set.targetReps {
                set.weight = weight
                set.reps = reps + extra
            } else {
                set.weight = Progression.roundDown(
                    converted(calibrationLoad(exercise.info?.equipment), unit),
                    to: exercise.increment(unit))
                set.reps = Progression.startingReps(in: exercise.repRange) + 1
            }
            set.isDone = true
        }
    }

    private static func calibrationLoad(_ equipment: Equipment?) -> Double {
        switch equipment {
        case .barbell: 135
        case .dumbbell: 30
        case .cable: 50
        case .smith: 115
        case .bodyweight: 0
        case .machine, nil: 100
        }
    }

    private static func converted(_ pounds: Double, _ unit: WeightUnit) -> Double {
        unit == .lb ? pounds : (pounds * 0.4536).rounded()
    }
}
