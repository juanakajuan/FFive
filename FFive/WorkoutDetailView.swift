import SwiftUI
import SwiftData

struct WorkoutDetailView: View {
    let workout: Workout
    @AppStorage("weightUnit") private var unit: WeightUnit = .lb

    var body: some View {
        let feedback = workout.feedback.compactMap { record in record.muscle.map { ($0, record.value) } }
            .sorted { $0.0.displayName < $1.0.displayName }
        ScrollView {
            VStack(spacing: 16) {
                summary
                ForEach(workout.sortedExercises.filter { $0.sets.contains(where: \.isDone) }) { exercise in
                    LoggedExerciseCard(exercise: exercise, unit: unit)
                }
                if !feedback.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("How it felt")
                            .font(Theme.cardTitle)
                            .foregroundStyle(Theme.text)
                            .padding(.horizontal, Theme.gutter)
                            .padding(.bottom, 8)
                        ForEach(feedback, id: \.0) { muscle, value in
                            Rectangle().fill(Theme.hairline).frame(height: 1).padding(.horizontal, Theme.gutter)
                            VStack(alignment: .leading, spacing: 6) {
                                MuscleTag(muscle: muscle)
                                Text([value.pump.map { "Pump: \($0.label)" },
                                      value.workload.map { "Workload: \($0.label)" },
                                      value.jointPain.map { "Joints: \($0.label)" },
                                      value.soreness.map { "Afterwards: \($0.label)" }]
                                    .compactMap { $0 }.joined(separator: " · "))
                                    .font(Theme.detail)
                                    .foregroundStyle(Theme.secondary)
                            }
                            .padding(.horizontal, Theme.gutter)
                            .padding(.vertical, 10)
                            .accessibilityElement(children: .combine)
                        }
                    }
                    .surfaceCard()
                }
            }
            .padding(.bottom, 16)
        }
        .background(Theme.page)
        .navigationTitle(workout.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(workout.startDate, format: .dateTime.weekday(.wide).month(.wide).day().hour().minute())
                    .font(Theme.body.weight(.semibold))
                    .foregroundStyle(Theme.text)
                if let meso = workout.mesocycle, let week = workout.week, let phase = workout.phase {
                    Text("\(meso.name) · \(phase == .deload ? "Deload week" : "Week \(week + 1), \(phase.badgeText)")")
                        .font(Theme.detail)
                        .foregroundStyle(Theme.secondary)
                }
            }
            HStack(spacing: 8) {
                StatTile(title: "Duration", value: formatDuration(workout.duration), icon: "clock")
                StatTile(title: "Sets", value: "\(workout.completedSets)", icon: "checkmark.circle")
                StatTile(title: "Volume (\(unit.rawValue))",
                         value: Int(workout.totalVolume).formatted(),
                         icon: "scalemass")
            }
            .fixedSize(horizontal: false, vertical: true)
            if let note = workout.note {
                Callout(text: note, systemImage: "note.text", style: .note)
                    .accessibilityLabel("Workout note: \(note)")
            }
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.bottom, 8)
        .surfaceCard()
    }
}

private struct LoggedExerciseCard: View {
    let exercise: Exercise
    let unit: WeightUnit

    var body: some View {
        let sets = exercise.sortedSets.filter(\.isDone)
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                if let muscle = exercise.muscle { MuscleTag(muscle: muscle) }
                Text(exercise.name)
                    .font(Theme.cardTitle)
                    .foregroundStyle(Theme.text)
                    .accessibilityAddTraits(.isHeader)
                if let note = exercise.note {
                    Callout(text: note, systemImage: "note.text", style: .note)
                        .accessibilityLabel("Note: \(note)")
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, 12)

            HStack(spacing: 0) {
                Text("Set").frame(width: 32, alignment: .leading)
                Text("Weight").frame(maxWidth: .infinity)
                Text("Reps").frame(maxWidth: .infinity)
            }
            .font(Theme.columnHeader)
            .textCase(.uppercase)
            .foregroundStyle(Theme.secondary)
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, 8)
            .accessibilityHidden(true)

            ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
                Rectangle().fill(Theme.hairline).frame(height: 1).padding(.horizontal, Theme.gutter)
                HStack(spacing: 0) {
                    Text("\(index + 1)")
                        .foregroundStyle(Theme.secondary)
                        .frame(width: 32, alignment: .leading)
                    Text("\(formatWeight(set.weight)) \(unit.rawValue)").frame(maxWidth: .infinity)
                    Text("\(set.reps)").frame(maxWidth: .infinity)
                }
                .font(Theme.body.monospacedDigit())
                .foregroundStyle(Theme.text)
                .padding(.horizontal, Theme.gutter)
                .frame(minHeight: 44)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Set \(index + 1), \(formatWeight(set.weight)) \(unit.rawValue) × \(set.reps)")
            }
        }
        .surfaceCard()
    }
}
