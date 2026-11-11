import FFiveCore
import SwiftUI

/// Every finished session of one exercise, newest first, grouped by mesocycle.
struct ExerciseHistorySheet: View {
    let name: String

    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let groups = store.exerciseHistory(ExerciseID(folding: name))
        let offsets = groups.indices.map { groups[..<$0].reduce(0) { $0 + $1.sessions.count } }
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(groups.enumerated()), id: \.element.id) { groupIndex, group in
                        SectionHeading(text: group.mesocycle?.name ?? "Quick Workouts")
                            .padding(.horizontal, Theme.gutter)
                        ForEach(Array(group.sessions.enumerated()), id: \.element.id) { index, session in
                            if let workout = session.workout {
                                NavigationLink(value: workout) { SessionRow(session: session, workout: workout) }
                                    .buttonStyle(.plain)
                                    .a11y(.exerciseHistorySession, offsets[groupIndex] + index + 1)
                            }
                        }
                    }
                }
                .padding(.bottom, Theme.gutter)
            }
            .overlay {
                if groups.isEmpty {
                    EmptyState(
                        "No sessions yet", systemImage: "clock.arrow.circlepath",
                        message: "Finished sessions with this exercise show up here.")
                }
            }
            .background(Theme.surface)
            .navigationTitle(name)
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Workout.self) { WorkoutDetailView(workout: $0) }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .a11y(.sheetDone)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct SessionRow: View {
    let session: Exercise
    let workout: Workout

    @Environment(Store.self) private var store

    private var title: String {
        guard let key = workout.key, let phase = workout.phase else { return workout.name }
        return "\(phase.longLabel(week: key.week)) · Day \(key.dayIndex + 1) · \(workout.name)"
    }

    var body: some View {
        let unit = store.settings.weightUnit
        let sets = session.sortedSets.filter(\.isDone)
        let setTexts = sets.map { set in
            "\(set.weightText(unit: unit)) × \(set.reps)" + (set.type.tag.map { " \($0)" } ?? "")
        }
        let date = workout.startDate.formatted(.sessionDay)
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(Theme.rowTitle)
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(date)
                        .font(Theme.caption)
                        .foregroundStyle(Theme.secondary)
                }
                ForEach(Array(setTexts.enumerated()), id: \.offset) { index, text in
                    HStack {
                        Text("Set \(index + 1)").foregroundStyle(Theme.secondary)
                        Spacer()
                        Text(text).monospacedDigit().foregroundStyle(Theme.text)
                    }
                    .font(Theme.detail)
                }
            }
            RowChevron()
                .padding(.top, 4)
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) { Hairline() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(title), \(date). "
                + setTexts.enumerated().map { "Set \($0.offset + 1), \($0.element)" }.joined(separator: ". ")
        )
        .accessibilityHint("Opens the workout")
    }
}
