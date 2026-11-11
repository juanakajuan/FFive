import FFiveCore
import SwiftUI

/// Asks pump, workload and joint pain on a draft; Save writes all three, Cancel drops them.
struct FeedbackSheet: View {
    let muscle: Muscle
    let original: MuscleFeedback
    let onSave: (MuscleFeedback) -> Void

    @State private var draft: MuscleFeedback

    init(muscle: Muscle, feedback: MuscleFeedback, onSave: @escaping (MuscleFeedback) -> Void) {
        self.muscle = muscle
        self.original = feedback
        self.onSave = onSave
        _draft = State(initialValue: feedback)
    }

    var body: some View {
        DraftSheet(
            "\(muscle.displayName) Feedback", isDirty: draft != original, canSave: draft.isRated,
            cancelID: .feedbackCancel, saveID: .feedbackSave
        ) {
            onSave(draft)
        } content: {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("How did \(muscle.displayName.lowercased()) feel today?")
                        .font(Theme.cardTitle)
                        .foregroundStyle(Theme.text)
                    ChipPicker(
                        title: "Pump", options: Pump.allCases, columns: 3, label: \.label, meaning: \.meaning,
                        selection: draft.pump
                    ) { draft.pump = $0 }
                    ChipPicker(
                        title: "Workload", options: Workload.allCases, columns: 2, label: \.label, meaning: \.meaning,
                        selection: draft.workload
                    ) { draft.workload = $0 }
                    ChipPicker(
                        title: "Joint Pain", options: JointPain.allCases, columns: 4, label: \.label,
                        meaning: \.meaning,
                        selection: draft.jointPain
                    ) { draft.jointPain = $0 }
                    Text(
                        "Next week's sets for \(muscle.displayName.lowercased()) come from these answers and how sore you get."
                    )
                    .font(Theme.caption)
                    .foregroundStyle(Theme.secondary)
                }
                .padding(Theme.gutter)
            }
            .background(Theme.page)
        }
    }
}
