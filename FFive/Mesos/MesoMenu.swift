import FFiveCore
import SwiftUI

/// A mesocycle being renamed, with the name typed so far.
struct MesoRename {
    let meso: Mesocycle
    var name: String

    init(_ meso: Mesocycle) {
        self.meso = meso
        name = meso.name
    }
}

/// The items of a mesocycle's menu, shared by the Mesos row and the mesocycle page.
struct MesoMenuItems: View {
    let meso: Mesocycle
    @Binding var renaming: MesoRename?
    @Binding var ending: Mesocycle?
    @Binding var deleting: Mesocycle?

    var body: some View {
        ForEach(MesoAction.menu(for: meso), id: \.self) { action in
            switch action {
            case .summary:
                NavigationLink(value: MesoSummaryRoute(meso: meso)) {
                    Label("Summary", systemImage: "chart.bar")
                }
                .a11y(.menuSummary)
            case .rename:
                Button("Rename", systemImage: "pencil") { renaming = MesoRename(meso) }
                    .a11y(.menuRename)
            case .end:
                Button("End Mesocycle", systemImage: "flag.checkered", role: .destructive) { ending = meso }
                    .a11y(.menuEndMesocycle)
            case .delete:
                Button("Delete", systemImage: "trash", role: .destructive) { deleting = meso }
                    .a11y(.menuDeleteMesocycle)
            }
        }
    }
}

extension View {
    /// The rename alert that `MesoMenuItems` opens.
    func mesoRenameAlert(_ renaming: Binding<MesoRename?>, store: Store) -> some View {
        alert("Rename Mesocycle", isPresented: renaming.isPresent()) {
            TextField(
                "Mesocycle name",
                text: Binding(
                    get: { renaming.wrappedValue?.name ?? "" },
                    set: { renaming.wrappedValue?.name = $0 }
                )
            )
            Button("Save") {
                if let rename = renaming.wrappedValue { store.rename(rename.meso, to: rename.name) }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}
