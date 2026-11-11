import FFiveCore
import SwiftUI

/// A custom template being renamed, with the name typed so far.
struct TemplateRename {
    let saved: CustomTemplate
    var name: String

    init(_ saved: CustomTemplate) {
        self.saved = saved
        name = saved.name
    }
}

/// Copy for any template, then Rename and Delete for a custom one.
struct TemplateMenuItems: View {
    let template: ProgramTemplate
    let saved: CustomTemplate?
    @Binding var builder: MesoBuilderView.Route?
    @Binding var renaming: TemplateRename?
    @Binding var deleting: CustomTemplate?

    @Environment(Store.self) private var store

    var body: some View {
        Button("Copy", systemImage: "doc.on.doc") { builder = .editTemplate(store.copyTemplate(template)) }
            .a11y(.menuCopyTemplate)
        if let saved {
            Button("Rename", systemImage: "pencil") { renaming = TemplateRename(saved) }
                .a11y(.menuRenameTemplate)
            Button("Delete", systemImage: "trash", role: .destructive) { deleting = saved }
                .a11y(.menuDeleteTemplate)
        }
    }
}

extension View {
    /// The rename alert and delete dialog that `TemplateMenuItems` opens.
    func templateActions(
        renaming: Binding<TemplateRename?>, deleting: Binding<CustomTemplate?>, store: Store,
        onDelete: @escaping () -> Void = {}
    ) -> some View {
        alert("Rename Template", isPresented: renaming.isPresent()) {
            TextField(
                "Template name",
                text: Binding(
                    get: { renaming.wrappedValue?.name ?? "" },
                    set: { renaming.wrappedValue?.name = $0 }
                )
            )
            Button("Save") {
                if let rename = renaming.wrappedValue { store.rename(rename.saved, to: rename.name) }
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            "Delete this template?",
            isPresented: deleting.isPresent(),
            titleVisibility: .visible, presenting: deleting.wrappedValue
        ) { saved in
            Button("Delete Template", role: .destructive) {
                store.delete(saved)
                onDelete()
            }
            .a11y(.dialogDeleteTemplate)
        } message: { saved in
            Text(
                "\(saved.name) is removed from your templates. Mesocycles started from it keep their plan. This can't be undone."
            )
        }
    }
}
