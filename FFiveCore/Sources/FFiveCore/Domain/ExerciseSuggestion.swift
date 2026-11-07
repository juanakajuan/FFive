import Foundation

extension ExerciseListing {
    /// The exercise to suggest for `muscle` after `current`, cycling through every listing that trains the
    /// muscle and fits `equipment`. Exercises done before come first, most recently done first, then the
    /// rest by name. Nil when nothing fits.
    public static func suggestion(
        after current: ExerciseID?,
        in listings: [ExerciseListing],
        muscle: Muscle,
        equipment: Set<Equipment>,
        lastPerformed: [ExerciseID: Date]
    ) -> ExerciseListing? {
        let candidates =
            listings
            .filter { $0.muscle == muscle && !$0.isHidden && $0.fits(equipment) }
            .sorted { a, b in
                switch (lastPerformed[a.id], lastPerformed[b.id]) {
                case (let x?, let y?) where x != y: x > y
                case (_?, nil): true
                case (nil, _?): false
                default: a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
                }
            }
        guard let index = candidates.firstIndex(where: { $0.id == current }) else { return candidates.first }
        return candidates[(index + 1) % candidates.count]
    }
}
