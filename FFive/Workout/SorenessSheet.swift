import FFiveCore
import SwiftUI

/// Asks how a muscle recovered since its last session, before its first set today is logged.
struct SorenessSheet: View {
    let muscle: Muscle
    let record: MuscleFeedbackRecord
    let onSave: (Soreness) -> Void

    @State private var draft: Soreness?

    var body: some View {
        DraftSheet(
            "\(muscle.displayName) Recovery", isDirty: draft != nil, canSave: draft != nil,
            cancelID: .sorenessCancel, saveID: .sorenessSave
        ) {
            if let draft { onSave(draft) }
        } content: {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("How did your \(muscle.displayName.lowercased()) recover?")
                            .font(Theme.cardTitle)
                            .foregroundStyle(Theme.text)
                        if let previous = record.workout {
                            Text("Since \(previous.name), \(previous.startDate.formatted(.dateTime.weekday(.wide)))")
                                .font(Theme.detail)
                                .foregroundStyle(Theme.secondary)
                        }
                    }
                    ChipPicker(
                        title: "Soreness After That Session", options: Soreness.allCases, columns: 2,
                        label: \.label, meaning: \.meaning, selection: draft
                    ) { draft = $0 }
                    Text("Today's sets for \(muscle.displayName.lowercased()) are planned from this answer.")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.secondary)
                }
                .padding(Theme.gutter)
            }
            .background(Theme.page)
        }
    }
}
