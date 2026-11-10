import FFiveCore
import SwiftUI

/// A sheet that edits a draft: Cancel drops it, Save commits it, and a changed draft blocks swipe to dismiss.
struct DraftSheet<Content: View>: View {
    let title: String
    let isDirty: Bool
    let canSave: Bool
    let detents: Set<PresentationDetent>
    let cancelID: A11y
    let saveID: A11y
    /// Throwing keeps the sheet open, so the content can show why the save failed.
    let save: () throws -> Void
    let content: Content

    @Environment(\.dismiss) private var dismiss

    init(
        _ title: String, isDirty: Bool, canSave: Bool = true, detents: Set<PresentationDetent> = [.medium, .large],
        cancelID: A11y, saveID: A11y, save: @escaping () throws -> Void, @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.isDirty = isDirty
        self.canSave = canSave
        self.detents = detents
        self.cancelID = cancelID
        self.saveID = saveID
        self.save = save
        self.content = content()
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                            .a11y(cancelID)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            if (try? save()) != nil { dismiss() }
                        }
                        .disabled(!canSave)
                        .a11y(saveID)
                    }
                }
        }
        .presentationDetents(detents)
        .interactiveDismissDisabled(isDirty)
    }
}
