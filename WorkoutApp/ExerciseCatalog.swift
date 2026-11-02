import Foundation

// SKETCH: the catalog worker replaces this file.

enum ExerciseCatalog {
    static let all: [ExerciseInfo] = []
    static let templates: [ProgramTemplate] = []

    static func info(named name: String) -> ExerciseInfo? {
        all.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    static func exercises(for muscle: Muscle) -> [ExerciseInfo] {
        all.filter { $0.muscle == muscle }
    }
}
