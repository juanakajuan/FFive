import FFiveCore
import SwiftData
import SwiftUI

struct MesoDetailView: View {
    let meso: Mesocycle

    @Environment(Store.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var confirmEnd = false
    @State private var trainAfterAll: SessionKey?
    @State private var templateName: String?
    @State private var renameDraft: String?

    var body: some View {
        let week = meso.nextUp?.week ?? meso.accumulationWeeks
        ScrollView {
            VStack(spacing: Theme.gutter) {
                header(week: week)
                MesoScheduleGrid(meso: meso, onOpen: open, onSkipped: { trainAfterAll = $0 })
                WeekVolumeCard(meso: meso, week: week)
                MusclePrioritiesCard(meso: meso)
                Button("Save as Template") { templateName = meso.name }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
                    .a11y(.mesoSaveTemplate)
                if meso.isActive {
                    Button("End Mesocycle", role: .destructive) { confirmEnd = true }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.danger)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
                }
            }
            .padding(.bottom, Theme.gutter)
        }
        .background(Theme.page)
        .navigationTitle(meso.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    NavigationLink(value: MesoSummaryRoute(meso: meso)) {
                        Label("Summary", systemImage: "chart.bar")
                    }
                    .a11y(.menuSummary)
                    Button("Rename", systemImage: "pencil") { renameDraft = meso.name }
                        .a11y(.menuRename)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Mesocycle menu")
                .a11y(.mesoMenu)
            }
        }
        .alert(
            "Rename Mesocycle",
            isPresented: Binding(get: { renameDraft != nil }, set: { if !$0 { renameDraft = nil } })
        ) {
            TextField("Mesocycle name", text: Binding(get: { renameDraft ?? "" }, set: { renameDraft = $0 }))
            Button("Save") {
                if let name = renameDraft { store.rename(meso, to: name) }
            }
            Button("Cancel", role: .cancel) {}
        }
        .trainAfterAllDialog($trainAfterAll, of: meso, store: store, onOpen: open)
        .confirmationDialog("End this mesocycle?", isPresented: $confirmEnd, titleVisibility: .visible) {
            Button("End Mesocycle", role: .destructive) { router.end(meso, store: store) }
                .a11y(.dialogEndMesocycle)
        } message: {
            Text("Logged sessions stay in Progress. You can plan a new block right after.")
        }
        .alert(
            "Save as Template",
            isPresented: Binding(get: { templateName != nil }, set: { if !$0 { templateName = nil } })
        ) {
            TextField("Template name", text: Binding(get: { templateName ?? "" }, set: { templateName = $0 }))
            Button("Save") {
                if let templateName { store.saveTemplate(from: meso, named: templateName) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Saves this block's days and exercises so you can start a new one from them.")
        }
    }

    private func open(_ key: SessionKey) {
        router.openSession(key, in: meso)
    }

    private func header(week: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(meso.name)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Theme.text)
            HStack(spacing: 8) {
                Text(meso.isActive ? "Week \(week + 1) of \(meso.totalWeeks)" : "\(meso.totalWeeks) weeks")
                    .font(Theme.detail)
                    .foregroundStyle(Theme.secondary)
                if meso.isActive {
                    PhaseBadge(phase: meso.phase(week: week))
                } else {
                    StatusBadge(text: "Finished")
                }
            }
        }
        .padding(Theme.gutter)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
    }
}
