import Foundation
import SwiftData

@Model
final class Workout {
    var name: String
    var startDate: Date
    var endDate: Date?
    @Relationship(deleteRule: .cascade, inverse: \Exercise.workout)
    var exercises: [Exercise] = []

    init(name: String, startDate: Date = .now) {
        self.name = name
        self.startDate = startDate
    }

    var sortedExercises: [Exercise] { exercises.sorted { $0.order < $1.order } }
    var duration: TimeInterval { (endDate ?? .now).timeIntervalSince(startDate) }
    var completedSets: Int { exercises.reduce(0) { $0 + $1.sets.filter(\.isDone).count } }
    var totalVolume: Double {
        exercises.flatMap(\.sets).filter(\.isDone).reduce(0) { $0 + Double($1.reps) * $1.weight }
    }
}

@Model
final class Exercise {
    var name: String
    var order: Int
    var workout: Workout?
    @Relationship(deleteRule: .cascade, inverse: \SetEntry.exercise)
    var sets: [SetEntry] = []

    init(name: String, order: Int) {
        self.name = name
        self.order = order
    }

    var sortedSets: [SetEntry] { sets.sorted { $0.order < $1.order } }
}

@Model
final class SetEntry {
    var reps: Int
    var weight: Double
    var isDone: Bool = false
    var order: Int
    var exercise: Exercise?

    init(reps: Int, weight: Double, order: Int) {
        self.reps = reps
        self.weight = weight
        self.order = order
    }
}

enum ExerciseLibrary {
    static let groups: [(name: String, exercises: [String])] = [
        ("Chest", ["Bench Press", "Incline Bench Press", "Dumbbell Press", "Push-Up", "Cable Fly", "Dip"]),
        ("Back", ["Deadlift", "Pull-Up", "Barbell Row", "Dumbbell Row", "Lat Pulldown", "Seated Cable Row"]),
        ("Legs", ["Squat", "Front Squat", "Romanian Deadlift", "Leg Press", "Lunge", "Leg Curl", "Leg Extension", "Calf Raise"]),
        ("Shoulders", ["Overhead Press", "Dumbbell Shoulder Press", "Lateral Raise", "Face Pull", "Rear Delt Fly"]),
        ("Arms", ["Barbell Curl", "Dumbbell Curl", "Hammer Curl", "Tricep Pushdown", "Skull Crusher"]),
        ("Core", ["Plank", "Hanging Leg Raise", "Cable Crunch", "Ab Wheel"]),
    ]

    static let all: [String] = groups.flatMap(\.exercises)
}

func formatDuration(_ interval: TimeInterval) -> String {
    let minutes = max(0, Int(interval) / 60)
    return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
}
