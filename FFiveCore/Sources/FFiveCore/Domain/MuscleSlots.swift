import Foundation

extension MesoDraft {
    /// Gives every empty slot the first exercise for its muscle, in suggestion order, that its day doesn't already
    /// hold. A slot stays empty when its day holds every exercise that fits.
    public mutating func autofill(
        from listings: [ExerciseListing], equipment: Set<Equipment>, lastPerformed: [ExerciseID: Date]
    ) {
        for day in days.indices {
            var taken = Set(days[day].slots.compactMap { $0.exercise.map(ExerciseID.init(folding:)) })
            for slot in days[day].slots.indices where days[day].slots[slot].exercise == nil {
                let pick = ExerciseListing.ranked(
                    listings, muscle: days[day].slots[slot].muscle, equipment: equipment, lastPerformed: lastPerformed
                ).first { !taken.contains($0.id) }
                guard let pick else { continue }
                days[day].slots[slot].exercise = pick.name
                taken.insert(pick.id)
            }
        }
    }

    public mutating func clearExercises() {
        for day in days.indices {
            for slot in days[day].slots.indices { days[day].slots[slot].exercise = nil }
        }
    }
}
