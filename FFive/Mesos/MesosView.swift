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
                    .a11y(.mesosNew)
            }
            .navigationDestination(for: Mesocycle.self) { MesoDetailView(meso: $0) }
            .navigationDestination(for: Workout.self) { WorkoutDetailView(workout: $0) }
            .navigationDestination(for: MesoSummaryRoute.self) { MesoSummaryView(meso: $0.meso) }
            .sheet(isPresented: $showingBuilder) { MesoBuilderView() }
            .endMesocycleDialog($ending) { router.end($0, store: store) }
            .confirmationDialog(
                "Delete this mesocycle?",
                isPresented: $deleting.isPresent(),
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
                            "\(Text("\(meso.totalWeeks)").foregroundStyle(Theme.text)) weeks · \(Text("\(meso.days.count)").foregroundStyle(Theme.text))/week"
                        )
                        .font(Theme.caption.weight(.medium))
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
                    RowChevron()
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
        .frame(minHeight: 66)
        .browseRow()
    }

    private var emptyState: some View {
        EmptyState(
            "No mesocycles yet", systemImage: "calendar",
            message:
                "Plan a mesocycle of 3 to 6 hard weeks and a deload. Every week adjusts to how the last sessions felt."
        ) {
            Button("Plan a Mesocycle") { showingBuilder = true }
                .buttonStyle(.primary)
                .a11y(.mesosPlan)
        }
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
