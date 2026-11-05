import SwiftUI
import SwiftData

struct MesoDetailView: View {
    let meso: Mesocycle

    @Environment(\.modelContext) private var context
    @Environment(AppRouter.self) private var router
    @AppStorage("weightUnit") private var unit: WeightUnit = .lb
    @State private var confirmEnd = false

    private var isActive: Bool { meso.finishedDate == nil }

    var body: some View {
        let week = meso.nextUp?.week ?? meso.accumulationWeeks
        ScrollView {
            VStack(spacing: Theme.gutter) {
                header(week: week)
                MesoScheduleGrid(meso: meso) { key in
                    if isActive { router.openSession(key) }
                }
                WeekVolumeCard(meso: meso, week: week, unit: unit)
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
        .confirmationDialog("End this mesocycle?", isPresented: $confirmEnd, titleVisibility: .visible) {
            Button("End Mesocycle", role: .destructive, action: end)
        } message: {
            Text("Logged sessions stay in Progress. You can plan a new block right after.")
        }
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

    private func end() {
        meso.finishedDate = .now
        try? context.save()
    }
}
