import FFiveCore
import SwiftUI

struct ReorderExercisesView: View {
    let workout: Workout

    @Environment(Store.self) private var store

    @State private var draft: [Exercise]
    @State private var scope = PlanScope.laterWeeks

    init(workout: Workout) {
        self.workout = workout
        _draft = State(initialValue: workout.sortedExercises)
    }

    var body: some View {
        DraftSheet(
            "Reorder Exercises", isDirty: draft != workout.sortedExercises,
            cancelID: .reorderCancel, saveID: .reorderSave
        ) {
            store.reorderExercises(of: workout, to: draft, scope: scope)
        } content: {
            List {
                if workout.mesocycle != nil {
                    Section {
                        SegmentedButtons(
                            options: [PlanScope.thisSession, .laterWeeks], selection: $scope
                        ) { $0 == .thisSession ? "This Session Only" : "Later Weeks Too" }
                        Text(
                            scope == .thisSession
                                ? "Later weeks keep the order they have now."
                                : "Later weeks of this day are planned in this order."
                        )
                        .font(Theme.caption)
                        .foregroundStyle(Theme.secondary)
                    }
                    .themedRow()
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
                        .themedRow()
                    }
                    .onMove { draft.move(fromOffsets: $0, toOffset: $1) }
                }
            }
            .themedList(background: Theme.page)
            .environment(\.editMode, .constant(.active))
        }
    }
}
