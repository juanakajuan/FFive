import FFiveCore
import SwiftData
import SwiftUI

struct ExerciseDetailView: View {
    let listing: ExerciseListing

    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var editing: CustomExercise?
    @State private var confirmingDelete = false
    @Query private var logged: [Exercise]

    init(listing: ExerciseListing) {
        self.listing = listing
        let key = listing.id.rawValue
        _logged = Query(filter: #Predicate<Exercise> { $0.exerciseKey == key })
    }

    private struct Session: Identifiable {
        let workout: Workout
        let best: SetEntry
        var id: PersistentIdentifier { workout.persistentModelID }
    }

    private var history: [Session] {
        logged.compactMap { exercise in
            guard let workout = exercise.workout, workout.isFinished,
                let best = exercise.sets.filter(\.isDone).max(by: { ($0.weight, $0.reps) < ($1.weight, $1.reps) })
            else { return nil }
            return Session(workout: workout, best: best)
        }
        .sorted { $0.workout.startDate > $1.workout.startDate }
    }

    var body: some View {
        let history = history
        let current = store.listing(listing.id) ?? listing
        let reps = current.info.repRange
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 10) {
                    MuscleTag(muscle: current.muscle)
                    Text(current.name)
                        .font(Theme.heroTitle)
                        .foregroundStyle(Theme.text)
                    HStack(spacing: 6) {
                        Text(current.equipment)
                        Text("•")
                        Text("\(reps.lowerBound)–\(reps.upperBound) reps")
                    }
                    .font(Theme.detail)
                    .foregroundStyle(Theme.secondary)
                    if let last = history.first?.workout.startDate {
                        Text(last.lastPerformedPhrase())
                            .font(Theme.detail)
                            .foregroundStyle(Theme.secondary)
                            .a11y(.exerciseLastPerformed)
                    }
                    if let cue = current.info.cue {
                        Callout(text: cue, systemImage: "lightbulb")
                            .padding(.top, 4)
                    }
                    if current.isHidden {
                        Callout(text: "Hidden from pickers. Your history is kept.", systemImage: "eye.slash")
                    }
                    if let note = store.pinnedNote(named: current.name) {
                        Callout(text: note, systemImage: "note.text", style: .pinned)
                            .accessibilityLabel("Note: \(note)")
                    }
                }
                .padding(Theme.gutter)

                SectionHeading(text: "History")
                    .padding(.horizontal, Theme.gutter)
                if history.isEmpty {
                    Text("Sessions you finish with this exercise show up here.")
                        .font(Theme.detail)
                        .foregroundStyle(Theme.secondary)
                        .padding(.horizontal, Theme.gutter)
                        .padding(.vertical, 8)
                }
                ForEach(history) { session in
                    NavigationLink(value: session.workout) { historyRow(session) }
                        .buttonStyle(.plain)
                }
            }
        }
        .background(Theme.surface)
        .navigationTitle(current.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) { actions(current) }
        }
        .sheet(item: $editing) { custom in
            CustomExerciseEditor(draft: CustomExerciseDraft(custom), editing: custom) { saved in
                if saved.id != listing.id { dismiss() }
            }
        }
        .confirmationDialog("Delete this exercise?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete Exercise", role: .destructive) {
                if let custom = store.customExercise(listing.id) {
                    store.deleteCustomExercise(custom)
                    dismiss()
                }
            }
            .a11y(.dialogDeleteExercise)
        } message: {
            Text(
                "Your history is kept. If you have logged it or planned it, it is archived and hidden from pickers instead of removed."
            )
        }
    }

    private func actions(_ current: ExerciseListing) -> some View {
        Menu {
            if current.isCustom {
                Button("Edit", systemImage: "pencil") { editing = store.customExercise(current.id) }
                    .a11y(.detailEdit)
            }
            Button(
                current.isHidden ? "Show in pickers" : "Hide from pickers",
                systemImage: current.isHidden ? "eye" : "eye.slash"
            ) { store.setHidden(current.id, !current.isHidden) }
            .a11y(.detailHide)
            if current.isCustom {
                Button("Delete", systemImage: "trash", role: .destructive) { confirmingDelete = true }
                    .a11y(.detailDelete)
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel("Exercise actions")
    }

    private func historyRow(_ session: Session) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(session.workout.startDate, format: .sessionDay)
                    .font(Theme.body)
                    .foregroundStyle(Theme.text)
                Text(session.workout.name)
                    .font(Theme.caption)
                    .foregroundStyle(Theme.secondary)
            }
            Spacer(minLength: 8)
            Text("\(session.best.weightText(unit: store.settings.weightUnit)) × \(session.best.reps)")
                .font(Theme.body.monospacedDigit())
                .foregroundStyle(Theme.text)
            RowChevron()
        }
        .frame(minHeight: 60)
        .browseRow()
    }
}
