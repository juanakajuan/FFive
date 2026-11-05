import SwiftUI
import SwiftData
import FFiveCore

/// One block's schedule and the current week's volume, pushed from the Mesos tab.
struct MesoDetailView: View {
    let meso: Mesocycle

    @Environment(Store.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var confirmEnd = false
    @State private var trainAfterAll: SessionKey?

    private var isActive: Bool { meso.finishedDate == nil }

    var body: some View {
        let week = meso.nextUp?.week ?? meso.accumulationWeeks
        ScrollView {
            VStack(spacing: Theme.gutter) {
                header(week: week)
                // Only the active block trains from the Workout tab, so a finished block's days don't open anything.
                MesoScheduleGrid(meso: meso, onOpen: open, onSkipped: { trainAfterAll = $0 })
                WeekVolumeCard(meso: meso, week: week)
                if isActive {
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
        .trainAfterAllDialog($trainAfterAll, of: meso, store: store, onOpen: open)
        .confirmationDialog("End this mesocycle?", isPresented: $confirmEnd, titleVisibility: .visible) {
            Button("End Mesocycle", role: .destructive) { store.endMesocycle(meso) }
                .a11y(.dialogEndMesocycle)
        } message: {
            Text("Logged sessions stay in Progress. You can plan a new block right after.")
        }
    }

    private func open(_ key: SessionKey) {
        if isActive { router.openSession(key, in: meso) }
    }

    private func header(week: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(meso.name)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Theme.text)
            HStack(spacing: 8) {
                Text(isActive ? "Week \(week + 1) of \(meso.totalWeeks)" : "\(meso.totalWeeks) weeks")
                    .font(Theme.detail)
                    .foregroundStyle(Theme.secondary)
                if isActive {
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
