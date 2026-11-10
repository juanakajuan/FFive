import FFiveCore
import SwiftUI

/// An exercise's name over its muscle and equipment, as the Exercises list and the picker show it.
struct ExerciseListingLabel: View {
    let listing: ExerciseListing
    var lastPerformed: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(listing.name)
                .font(Theme.body)
                .foregroundStyle(Theme.text)
            Group {
                HStack(spacing: 4) {
                    MuscleDotLabel(muscle: listing.muscle)
                    Text("•")
                    Text(listing.equipment)
                    if listing.isHidden {
                        Text("•")
                        Text("Hidden")
                    }
                }
                if let lastPerformed {
                    Text(lastPerformed.lastPerformedPhrase())
                }
            }
            .font(Theme.caption)
            .foregroundStyle(Theme.secondary)
        }
    }
}
