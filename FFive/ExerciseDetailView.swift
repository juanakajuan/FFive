import SwiftUI
import SwiftData

/// An exercise's catalog facts and every finished session that logged it.
struct ExerciseDetailView: View {
    let listing: ExerciseListing

    @AppStorage("weightUnit") private var unit: WeightUnit = .lb
    @Query private var logged: [Exercise]

    init(listing: ExerciseListing) {
        self.listing = listing
        let name = listing.name
        _logged = Query(filter: #Predicate<Exercise> { $0.name == name })
    }

    private struct Session: Identifiable {
        let workout: Workout
        let best: SetEntry
        var id: PersistentIdentifier { workout.persistentModelID }
    }

    /// Finished sessions newest first, each with its heaviest done set (more reps breaks a tie).
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
        let reps = ExerciseCatalog.repRange(for: listing.name)
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 10) {
                    MuscleTag(muscle: listing.muscle)
                    Text(listing.name)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Theme.text)
                    HStack(spacing: 6) {
                        Text(listing.equipment)
                        Text("•")
                        Text("\(reps.lowerBound)–\(reps.upperBound) reps")
                    }
                    .font(Theme.detail)
                    .foregroundStyle(Theme.secondary)
                    if let cue = listing.info?.cue {
                        Callout(text: cue, systemImage: "lightbulb")
                            .padding(.top, 4)
                    }
                }
                .padding(Theme.gutter)

                SectionHeading(text: "History")
                    .padding(.horizontal, Theme.gutter)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
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
        .navigationTitle(listing.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func historyRow(_ session: Session) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(session.workout.startDate, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day().year())
                    .font(Theme.body)
                    .foregroundStyle(Theme.text)
                Text(session.workout.name)
                    .font(Theme.caption)
                    .foregroundStyle(Theme.secondary)
            }
            Spacer(minLength: 8)
            Text("\(formatWeight(session.best.weight)) \(unit.rawValue) × \(session.best.reps)")
                .font(Theme.body.monospacedDigit())
                .foregroundStyle(Theme.text)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.secondary)
        }
        .padding(.horizontal, Theme.gutter)
        .frame(minHeight: 60)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.hairline).frame(height: 1) }
    }
}
