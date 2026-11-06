import FFiveCore
import SwiftUI

struct ReorderExercisesView: View {
    let workout: Workout

    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var draft: [Exercise]
    @State private var scope = ReorderScope.laterWeeks

    init(workout: Workout) {
        self.workout = workout
        _draft = State(initialValue: workout.sortedExercises)
    }

    var body: some View {
        NavigationStack {
            List {
                if workout.mesocycle != nil {
                    Section {
                        SegmentedButtons(
                            options: [ReorderScope.thisSession, .laterWeeks], selection: $scope
                        ) { $0 == .thisSession ? "This session" : "Later weeks too" }
                        Text(
                            scope == .thisSession
                                ? "Later weeks keep the order they have now."
                                : "Later weeks of this day are planned in this order."
                        )
                        .font(Theme.caption)
                        .foregroundStyle(Theme.secondary)
                    }
                    .listRowBackground(Theme.surface)
                    .listRowSeparator(.hidden)
                }
                Section {
                    ForEach(draft) { exercise in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(exercise.name)
                                .font(Theme.body)
                                .foregroundStyle(Theme.text)
                            if let muscle = exercise.muscle { MuscleDotLabel(muscle: muscle) }
                        }
                        .listRowBackground(Theme.surface)
                        .listRowSeparatorTint(Theme.hairline)
                    }
                    .onMove { draft.move(fromOffsets: $0, toOffset: $1) }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.surface)
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Reorder Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .a11y(.reorderCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.reorderExercises(of: workout, to: draft, scope: scope)
                        dismiss()
                    }
                    .a11y(.reorderSave)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
