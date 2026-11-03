import SwiftUI
import SwiftData

struct MesosView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Mesocycle.startDate, order: .reverse) private var mesos: [Mesocycle]

    @State private var path = NavigationPath()
    @State private var showingBuilder = false
    @State private var ending: Mesocycle?

    /// The Workout tab trains the newest unfinished block, so that one is "current".
    private var current: Mesocycle? { mesos.first { $0.finishedDate == nil } }

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
                // Starting a block doesn't end the current one, so creation waits until it is ended.
                HeaderAddButton(label: "New Mesocycle") { showingBuilder = true }
                    .disabled(current != nil)
            }
            .navigationDestination(for: Mesocycle.self) { MesoDetailView(meso: $0) }
            .navigationDestination(for: Workout.self) { WorkoutDetailView(workout: $0) }
            .sheet(isPresented: $showingBuilder) { MesoBuilderView() }
            .confirmationDialog("End this mesocycle?",
                                isPresented: Binding(get: { ending != nil }, set: { if !$0 { ending = nil } }),
                                titleVisibility: .visible, presenting: ending) { meso in
                Button("End Mesocycle", role: .destructive) { end(meso) }
            } message: { _ in
                Text("Logged sessions stay in Progress. You can plan a new block right after.")
            }
        }
    }

    private func row(_ meso: Mesocycle) -> some View {
        let isCurrent = meso === current
        return HStack(spacing: 12) {
            Button { path.append(meso) } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(meso.name)
                            .font(Theme.cardTitle)
                            .foregroundStyle(Theme.text)
                            .lineLimit(1)
                        Text("\(Text("\(meso.totalWeeks)").foregroundStyle(Theme.text)) WEEKS - \(Text("\(meso.days.count)").foregroundStyle(Theme.text)) DAYS/WEEK")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(Theme.secondary)
                    }
                    Spacer(minLength: 8)
                    if isCurrent {
                        StatusBadge(text: "Current")
                    } else if meso.finishedDate != nil {
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

            Menu {
                if isCurrent {
                    Button("End Mesocycle", systemImage: "flag.checkered", role: .destructive) { ending = meso }
                } else {
                    Button("View", systemImage: "eye") { path.append(meso) }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .rotationEffect(.degrees(90))
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.text)
                    .frame(width: 24, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("\(meso.name) menu")
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
        }
        .padding(Theme.gutter * 2)
    }

    private func end(_ meso: Mesocycle) {
        meso.end(in: context)
        try? context.save()
    }
}

#Preview {
    MesosView()
        .environment(AppRouter())
        .modelContainer(AppStore.makeContainer(inMemory: true))
        .preferredColorScheme(.dark)
}
