import FFiveCore
import SwiftData
import SwiftUI

struct MesosView: View {
    @Environment(Store.self) private var store
    @Environment(AppRouter.self) private var router
    @Query(sort: \Mesocycle.startDate, order: .reverse) private var mesos: [Mesocycle]

    @State private var path = NavigationPath()
    @State private var showingBuilder = false
    @State private var ending: Mesocycle?
    @State private var deleting: Mesocycle?

    private var current: Mesocycle? { mesos.first(where: \.isActive) }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if mesos.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(mesos) { row($0) }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.surface)
            .screenHeader("Mesocycles") {
                HeaderAddButton(label: "New Mesocycle") { showingBuilder = true }
                    .disabled(current != nil)
                    .a11y(.mesosNew)
            }
            .navigationDestination(for: Mesocycle.self) { MesoDetailView(meso: $0) }
            .navigationDestination(for: Workout.self) { WorkoutDetailView(workout: $0) }
            .navigationDestination(for: MesoSummaryRoute.self) { MesoSummaryView(meso: $0.meso) }
            .sheet(isPresented: $showingBuilder) { MesoBuilderView() }
            .confirmationDialog(
                "End this mesocycle?",
                isPresented: Binding(get: { ending != nil }, set: { if !$0 { ending = nil } }),
                titleVisibility: .visible, presenting: ending
            ) { meso in
                Button("End Mesocycle", role: .destructive) { router.end(meso, store: store) }
                    .a11y(.dialogEndMesocycle)
            } message: { _ in
                Text("Logged sessions stay in Progress. You can plan a new block right after.")
            }
            .confirmationDialog(
                "Delete this mesocycle?",
                isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                titleVisibility: .visible, presenting: deleting
            ) { meso in
                Button("Delete Mesocycle", role: .destructive) { router.delete(meso, store: store) }
                    .a11y(.dialogDeleteMesocycle)
            } message: { meso in
                Text(deleteMessage(meso))
            }
        }
    }

    private func row(_ meso: Mesocycle) -> some View {
        let isCurrent = meso === current
        return HStack(spacing: 12) {
            Button {
                path.append(meso)
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(meso.name)
                            .font(Theme.cardTitle)
                            .foregroundStyle(Theme.text)
                            .lineLimit(1)
                        Text(
                            "\(Text("\(meso.totalWeeks)").foregroundStyle(Theme.text)) WEEKS - \(Text("\(meso.days.count)").foregroundStyle(Theme.text)) DAYS/WEEK"
                        )
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(Theme.secondary)
                    }
                    Spacer(minLength: 8)
                    if isCurrent {
                        StatusBadge(text: "Current")
                    } else if !meso.isActive {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(Theme.text, Theme.success)
                            .accessibilityLabel("Finished")
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .a11y(.mesosRow, key: meso.name)

            Menu {
                if isCurrent {
                    Button("End Mesocycle", systemImage: "flag.checkered", role: .destructive) { ending = meso }
                        .a11y(.menuEndMesocycle)
                } else {
                    Button("View", systemImage: "eye") { path.append(meso) }
                        .a11y(.menuView)
                    Button("Summary", systemImage: "chart.bar") { path.append(MesoSummaryRoute(meso: meso)) }
                        .a11y(.menuSummary)
                }
                Button("Delete", systemImage: "trash", role: .destructive) { deleting = meso }
                    .a11y(.menuDeleteMesocycle)
            } label: {
                Image(systemName: "ellipsis")
                    .rotationEffect(.degrees(90))
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.text)
                    .frame(width: 24, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("\(meso.name) menu")
            .a11y(.mesosMenu, key: meso.name)
        }
        .padding(.horizontal, Theme.gutter)
        .frame(minHeight: 66)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.hairline).frame(height: 1) }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Text("No mesocycles yet")
                .font(Theme.cardTitle)
                .foregroundStyle(Theme.text)
            Text("Plan a block of 3 to 6 hard weeks and a deload. Every week adjusts to how the last sessions felt.")
                .font(Theme.detail)
                .foregroundStyle(Theme.secondary)
                .multilineTextAlignment(.center)
            FilledActionButton(title: "Plan a Mesocycle") { showingBuilder = true }
                .a11y(.mesosPlan)
        }
        .padding(Theme.gutter * 2)
    }
}

/// Shared by the list and the detail screen, so both confirmations name what goes with the block.
func deleteMessage(_ meso: Mesocycle) -> String {
    let count = meso.loggedWorkoutCount
    let workouts =
        switch count {
        case 0: "It has no logged workouts."
        case 1: "Its 1 logged workout leaves History and Progress."
        default: "Its \(count) logged workouts leave History and Progress."
        }
    return workouts + " This can't be undone."
}

#Preview {
    let store = Store(inMemory: true)
    return MesosView()
        .environment(AppRouter())
        .environment(store)
        .modelContainer(store.container)
        .preferredColorScheme(.dark)
}
